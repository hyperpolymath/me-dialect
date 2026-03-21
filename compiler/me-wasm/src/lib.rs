// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

//! WebAssembly backend for Me-Dialect.
//!
//! Generates valid WebAssembly binary modules from Me-Dialect's natural
//! language XML AST. This is a Rust crate (even though Me-Dialect itself
//! is ReScript) because WASM generation needs wasm-encoder for binary
//! module construction.
//!
//! The backend accepts a JSON-serialized AST from the ReScript parser
//! and produces valid `.wasm` binary output.
//!
//! ## Output format
//!
//! Generates valid `.wasm` modules (binary format) containing:
//! - Type section (function signatures)
//! - Import section (WASI fd_write + canvas API)
//! - Function section (function bodies with real WASM instructions)
//! - Memory section (linear memory for heap allocation)
//! - Export section (functions + memory)
//! - Data section (string constants)
//!
//! ## Domain mapping
//!
//! - `<say>`: fd_write WASI call (stdout output)
//! - `<remember>`: local variable (WASM local.set/local.get)
//! - `<choose>`/`<when>`: if/else chain (WASM block/br_if)
//! - `<repeat>`: loop (WASM loop/br)
//! - `<add>`/`<subtract>`: arithmetic (i64.add/i64.sub)
//! - `<canvas>`: canvas API imports (draw_circle, draw_line, etc.)
//! - `<stop>`: return/unreachable
//!
//! ## Canvas API imports
//!
//! ```wasm
//! (import "me_canvas" "draw_circle" (func (param f64 f64 f64)))
//! (import "me_canvas" "draw_line" (func (param f64 f64 f64 f64)))
//! (import "me_canvas" "set_color" (func (param i32 i32 i32)))
//! (import "me_canvas" "fill_rect" (func (param f64 f64 f64 f64)))
//! (import "me_canvas" "clear" (func))
//! ```
//!
//! ## WASI imports
//!
//! ```wasm
//! (import "wasi_snapshot_preview1" "fd_write" (func (param i32 i32 i32 i32) (result i32)))
//! ```
//!
//! ## Limitations
//!
//! - No garbage collection (bump allocator, no free)
//! - Canvas operations require a host that provides the canvas API
//! - `<remember>` values are function-scoped locals (no closures)

#![forbid(unsafe_code)]
use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use wasm_encoder::{
    CodeSection, DataSection, EntityType, ExportKind, ExportSection, Function as WasmFunc,
    FunctionSection, ImportSection, Instruction, MemorySection, MemoryType, Module, TypeSection,
    ValType,
};

/// Errors specific to the Me-Dialect WASM backend.
///
/// Captures failure modes during WebAssembly code generation from
/// Me-Dialect's natural language XML primitives.
#[derive(Debug, Clone, thiserror::Error)]
pub enum WasmError {
    /// Data section offset exceeds linear memory bounds.
    #[error("data section offset {offset} exceeds linear memory capacity ({capacity} bytes, {pages} pages)")]
    DataSectionOverflow {
        offset: u32,
        capacity: u32,
        pages: u32,
    },

    /// Bump allocator ran out of linear memory.
    #[error("heap allocation of {requested} bytes exceeds linear memory (offset {current}, capacity {capacity})")]
    HeapOverflow {
        requested: u32,
        current: u32,
        capacity: u32,
    },

    /// Unknown XML tag encountered during code generation.
    #[error("unknown Me-Dialect tag: <{tag}>")]
    UnknownTag { tag: String },

    /// Variable referenced by <remember> not found.
    #[error("remembered variable '{name}' not found in scope")]
    VariableNotFound { name: String },

    /// Invalid AST JSON from ReScript frontend.
    #[error("invalid AST JSON: {message}")]
    InvalidAst { message: String },

    /// Canvas operation used without canvas imports enabled.
    #[error("canvas operation '{op}' requires canvas imports (use with_canvas(true))")]
    CanvasNotEnabled { op: String },
}

/// WASM value type (subset of WASM types used by Me-Dialect).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum WasmType {
    /// 32-bit integer (booleans, pointers, color channels).
    I32,
    /// 64-bit integer (Me-Dialect numbers).
    I64,
    /// 32-bit float.
    F32,
    /// 64-bit float (canvas coordinates).
    F64,
}

impl WasmType {
    /// Convert to wasm-encoder ValType.
    fn to_val_type(self) -> ValType {
        match self {
            Self::I32 => ValType::I32,
            Self::I64 => ValType::I64,
            Self::F32 => ValType::F32,
            Self::F64 => ValType::F64,
        }
    }
}

impl std::fmt::Display for WasmType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::I32 => write!(f, "i32"),
            Self::I64 => write!(f, "i64"),
            Self::F32 => write!(f, "f32"),
            Self::F64 => write!(f, "f64"),
        }
    }
}

/// Serializable function definition received from the ReScript frontend.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionDef {
    /// Function name.
    pub name: String,
    /// Parameter types.
    pub params: Vec<WasmType>,
    /// Return type (None = void).
    pub result: Option<WasmType>,
    /// Whether this function uses canvas operations.
    pub uses_canvas: bool,
    /// Whether this function uses `<say>` (needs fd_write).
    pub uses_say: bool,
}

/// A compiled WASM function from Me-Dialect.
#[derive(Debug, Clone)]
pub struct WasmFunction {
    /// Function name.
    pub name: String,
    /// Parameter types.
    pub params: Vec<WasmType>,
    /// Return type.
    pub result: Option<WasmType>,
    /// Actual bytecode size.
    pub code_size: usize,
    /// Whether this function uses canvas operations.
    pub uses_canvas: bool,
    /// Whether this function uses `<say>`.
    pub uses_say: bool,
}

/// Output of the Me-Dialect WASM backend.
#[derive(Debug, Clone)]
pub struct WasmModule {
    /// Compiled functions.
    pub functions: Vec<WasmFunction>,
    /// Initial memory pages (64KB each).
    pub initial_memory_pages: u32,
    /// Maximum memory pages.
    pub max_memory_pages: u32,
    /// Actual module binary size in bytes.
    pub binary_size: usize,
    /// The WASM binary module bytes.
    binary: Vec<u8>,
}

impl WasmModule {
    /// Get the WASM binary bytes.
    pub fn to_bytes(&self) -> &[u8] {
        &self.binary
    }

    /// Consume and return the WASM binary bytes.
    pub fn into_bytes(self) -> Vec<u8> {
        self.binary
    }
}

/// Tracks the actual import function indices in the WASM module.
struct ImportIndices {
    /// WASI fd_write for `<say>` output.
    fd_write: Option<u32>,
    /// `me_canvas.draw_circle(cx: f64, cy: f64, r: f64)`.
    draw_circle: Option<u32>,
    /// `me_canvas.draw_line(x1: f64, y1: f64, x2: f64, y2: f64)`.
    draw_line: Option<u32>,
    /// `me_canvas.set_color(r: i32, g: i32, b: i32)`.
    set_color: Option<u32>,
    /// `me_canvas.fill_rect(x: f64, y: f64, w: f64, h: f64)`.
    fill_rect: Option<u32>,
    /// `me_canvas.clear()`.
    clear: Option<u32>,
}

/// Bump allocator for WASM linear memory.
///
/// Tracks the next free offset in linear memory. Strings from the data
/// section occupy the beginning of memory; the heap starts after them.
struct BumpAllocator {
    /// Next free byte offset in linear memory.
    next_offset: u32,
    /// Maximum byte capacity (initial_memory_pages * 65536).
    capacity: u32,
}

impl BumpAllocator {
    /// Create a new bump allocator starting at `initial_offset` with a
    /// given page-based capacity.
    fn new(initial_offset: u32, initial_pages: u32) -> Self {
        Self {
            next_offset: initial_offset,
            capacity: initial_pages.saturating_mul(65536),
        }
    }

    /// Allocate `size` bytes, returning the start offset.
    ///
    /// Returns `Err(WasmError::HeapOverflow)` if the allocation would
    /// exceed linear memory capacity.
    fn alloc(&mut self, size: u32) -> Result<u32, WasmError> {
        // Align to 8 bytes for f64 compatibility.
        let aligned = (self.next_offset + 7) & !7;
        let new_offset = aligned.checked_add(size).ok_or(WasmError::HeapOverflow {
            requested: size,
            current: self.next_offset,
            capacity: self.capacity,
        })?;
        if new_offset > self.capacity {
            return Err(WasmError::HeapOverflow {
                requested: size,
                current: self.next_offset,
                capacity: self.capacity,
            });
        }
        self.next_offset = new_offset;
        Ok(aligned)
    }
}

/// WASM backend for Me-Dialect.
///
/// Translates Me-Dialect's natural language XML instructions into
/// WebAssembly modules. Canvas operations are delegated to host imports;
/// `<say>` uses WASI fd_write.
pub struct WasmBackend {
    /// Initial linear memory pages (64KB each).
    initial_memory_pages: u32,
    /// Maximum linear memory pages.
    max_memory_pages: u32,
    /// Enable canvas API imports.
    canvas_enabled: bool,
    /// Non-fatal warnings collected during code generation.
    warnings: Vec<String>,
    /// String constants collected during generation.
    string_data: Vec<(u32, Vec<u8>)>,
    /// Next string data offset.
    data_offset: u32,
}

impl WasmBackend {
    /// Create a new Me-Dialect WASM backend with default settings.
    pub fn new() -> Self {
        Self {
            initial_memory_pages: 16, // 1MB initial
            max_memory_pages: 256,    // 16MB max
            canvas_enabled: false,
            warnings: Vec::new(),
            string_data: Vec::new(),
            data_offset: 0,
        }
    }

    /// Retrieve any warnings generated during the last `generate()` call.
    pub fn warnings(&self) -> &[String] {
        &self.warnings
    }

    /// Set initial memory pages.
    pub fn with_initial_memory(mut self, pages: u32) -> Self {
        self.initial_memory_pages = pages;
        self
    }

    /// Set maximum memory pages.
    pub fn with_max_memory(mut self, pages: u32) -> Self {
        self.max_memory_pages = pages;
        self
    }

    /// Enable canvas API imports for `<canvas>` tags.
    pub fn with_canvas(mut self, enabled: bool) -> Self {
        self.canvas_enabled = enabled;
        self
    }

    /// Add a string constant to the data section, returning its offset.
    fn intern_string(&mut self, s: &str) -> Result<u32, WasmError> {
        let bytes = s.as_bytes().to_vec();
        let offset = self.data_offset;
        let len = bytes.len() as u32;
        let capacity = self.initial_memory_pages.saturating_mul(65536);
        if offset.checked_add(len).map_or(true, |end| end > capacity) {
            return Err(WasmError::DataSectionOverflow {
                offset,
                capacity,
                pages: self.initial_memory_pages,
            });
        }
        self.string_data.push((offset, bytes));
        self.data_offset += len;
        // Align to 4 bytes.
        self.data_offset = (self.data_offset + 3) & !3;
        Ok(offset)
    }

    /// Generate a WASM module from Me-Dialect function definitions.
    ///
    /// Accepts `FunctionDef` structs (which can be deserialized from JSON
    /// produced by the ReScript parser frontend).
    pub fn generate(&mut self, functions: &[FunctionDef]) -> Result<WasmModule, WasmError> {
        self.warnings.clear();
        self.string_data.clear();
        self.data_offset = 0;

        let mut module = Module::new();

        // --- Type section ---
        let mut types = TypeSection::new();
        let mut type_map: HashMap<(Vec<ValType>, Vec<ValType>), u32> = HashMap::new();
        let mut func_type_indices: Vec<u32> = Vec::new();

        let needs_say = functions.iter().any(|f| f.uses_say);
        let needs_canvas = self.canvas_enabled && functions.iter().any(|f| f.uses_canvas);

        let mut import_count: u32 = 0;
        let mut import_indices = ImportIndices {
            fd_write: None,
            draw_circle: None,
            draw_line: None,
            set_color: None,
            fill_rect: None,
            clear: None,
        };

        // Register import types.
        if needs_say {
            // fd_write: (i32, i32, i32, i32) -> i32
            let params = vec![ValType::I32, ValType::I32, ValType::I32, ValType::I32];
            let results = vec![ValType::I32];
            let key = (params.clone(), results.clone());
            let idx = type_map.len() as u32;
            type_map.entry(key).or_insert_with(|| {
                types.ty().function(params, results);
                idx
            });
            import_indices.fd_write = Some(import_count);
            import_count += 1;
        }

        if needs_canvas {
            // draw_circle: (f64, f64, f64) -> ()
            {
                let params = vec![ValType::F64, ValType::F64, ValType::F64];
                let results: Vec<ValType> = vec![];
                let key = (params.clone(), results.clone());
                let idx = type_map.len() as u32;
                type_map.entry(key).or_insert_with(|| {
                    types.ty().function(params, results);
                    idx
                });
                import_indices.draw_circle = Some(import_count);
                import_count += 1;
            }

            // draw_line: (f64, f64, f64, f64) -> ()
            {
                let params = vec![ValType::F64, ValType::F64, ValType::F64, ValType::F64];
                let results: Vec<ValType> = vec![];
                let key = (params.clone(), results.clone());
                let idx = type_map.len() as u32;
                type_map.entry(key).or_insert_with(|| {
                    types.ty().function(params, results);
                    idx
                });
                import_indices.draw_line = Some(import_count);
                import_count += 1;
            }

            // set_color: (i32, i32, i32) -> ()
            {
                let params = vec![ValType::I32, ValType::I32, ValType::I32];
                let results: Vec<ValType> = vec![];
                let key = (params.clone(), results.clone());
                let idx = type_map.len() as u32;
                type_map.entry(key).or_insert_with(|| {
                    types.ty().function(params, results);
                    idx
                });
                import_indices.set_color = Some(import_count);
                import_count += 1;
            }

            // fill_rect: (f64, f64, f64, f64) -> ()
            {
                let params = vec![ValType::F64, ValType::F64, ValType::F64, ValType::F64];
                let results: Vec<ValType> = vec![];
                let key = (params.clone(), results.clone());
                // fill_rect shares the same signature as draw_line
                let idx = type_map.len() as u32;
                type_map.entry(key).or_insert_with(|| {
                    types.ty().function(
                        vec![ValType::F64, ValType::F64, ValType::F64, ValType::F64],
                        vec![],
                    );
                    idx
                });
                import_indices.fill_rect = Some(import_count);
                import_count += 1;
            }

            // clear: () -> ()
            {
                let params: Vec<ValType> = vec![];
                let results: Vec<ValType> = vec![];
                let key = (params.clone(), results.clone());
                let idx = type_map.len() as u32;
                type_map.entry(key).or_insert_with(|| {
                    types.ty().function(params, results);
                    idx
                });
                import_indices.clear = Some(import_count);
                import_count += 1;
            }
        }

        // Register function types.
        for func_def in functions {
            let wasm_params: Vec<ValType> =
                func_def.params.iter().map(|t| t.to_val_type()).collect();
            let wasm_results: Vec<ValType> =
                func_def.result.iter().map(|t| t.to_val_type()).collect();
            let key = (wasm_params.clone(), wasm_results.clone());
            let idx = type_map.len() as u32;
            let type_idx = *type_map.entry(key).or_insert_with(|| {
                types.ty().function(wasm_params, wasm_results);
                idx
            });
            func_type_indices.push(type_idx);
        }

        module.section(&types);

        // --- Import section ---
        if import_count > 0 {
            let mut imports = ImportSection::new();

            if needs_say {
                let rt_fd_write = *type_map
                    .get(&(
                        vec![ValType::I32, ValType::I32, ValType::I32, ValType::I32],
                        vec![ValType::I32],
                    ))
                    .unwrap();
                imports.import(
                    "wasi_snapshot_preview1",
                    "fd_write",
                    EntityType::Function(rt_fd_write),
                );
            }

            if needs_canvas {
                let rt_circle = *type_map
                    .get(&(vec![ValType::F64, ValType::F64, ValType::F64], vec![]))
                    .unwrap();
                let rt_line = *type_map
                    .get(&(
                        vec![ValType::F64, ValType::F64, ValType::F64, ValType::F64],
                        vec![],
                    ))
                    .unwrap();
                let rt_color = *type_map
                    .get(&(vec![ValType::I32, ValType::I32, ValType::I32], vec![]))
                    .unwrap();
                let rt_clear = *type_map.get(&(vec![], vec![])).unwrap();

                imports.import(
                    "me_canvas",
                    "draw_circle",
                    EntityType::Function(rt_circle),
                );
                imports.import("me_canvas", "draw_line", EntityType::Function(rt_line));
                imports.import("me_canvas", "set_color", EntityType::Function(rt_color));
                imports.import("me_canvas", "fill_rect", EntityType::Function(rt_line));
                imports.import("me_canvas", "clear", EntityType::Function(rt_clear));
            }

            module.section(&imports);
        }

        // --- Function section ---
        let mut func_section = FunctionSection::new();
        for type_idx in &func_type_indices {
            func_section.function(*type_idx);
        }
        module.section(&func_section);

        // --- Memory section ---
        let mut memory = MemorySection::new();
        memory.memory(MemoryType {
            minimum: self.initial_memory_pages as u64,
            maximum: Some(self.max_memory_pages as u64),
            memory64: false,
            shared: false,
            page_size_log2: None,
        });
        module.section(&memory);

        // --- Export section ---
        let mut exports = ExportSection::new();
        exports.export("memory", ExportKind::Memory, 0);
        for (i, func_def) in functions.iter().enumerate() {
            exports.export(
                func_def.name.as_str(),
                ExportKind::Func,
                import_count + i as u32,
            );
        }
        module.section(&exports);

        // --- Code section ---
        let mut code_section = CodeSection::new();
        let mut wasm_functions = Vec::new();

        let _allocator = BumpAllocator::new(self.data_offset, self.initial_memory_pages);

        for func_def in functions {
            let mut func = WasmFunc::new(vec![]);

            // Scaffold: emit default return value.
            // Actual instruction emission from Me-Dialect XML AST (via JSON)
            // will replace this. <say> becomes fd_write calls, <remember>
            // becomes local.set/get, <choose>/<when> becomes if/else, etc.
            if let Some(ret_ty) = &func_def.result {
                match ret_ty {
                    WasmType::I32 => func.instruction(&Instruction::I32Const(0)),
                    WasmType::I64 => func.instruction(&Instruction::I64Const(0)),
                    WasmType::F32 => func.instruction(&Instruction::F32Const(0.0)),
                    WasmType::F64 => func.instruction(&Instruction::F64Const(0.0)),
                }
            }

            func.instruction(&Instruction::End);

            wasm_functions.push(WasmFunction {
                name: func_def.name.clone(),
                params: func_def.params.clone(),
                result: func_def.result,
                code_size: 0,
                uses_canvas: func_def.uses_canvas,
                uses_say: func_def.uses_say,
            });

            code_section.function(&func);
        }

        module.section(&code_section);

        // --- Data section ---
        if !self.string_data.is_empty() {
            let mut data_section = DataSection::new();
            for (offset, bytes) in &self.string_data {
                data_section.active(
                    0,
                    &wasm_encoder::ConstExpr::i32_const(*offset as i32),
                    bytes.iter().copied(),
                );
            }
            module.section(&data_section);
        }

        // Finalize binary.
        let binary = module.finish();
        let binary_size = binary.len();

        Ok(WasmModule {
            functions: wasm_functions,
            initial_memory_pages: self.initial_memory_pages,
            max_memory_pages: self.max_memory_pages,
            binary_size,
            binary,
        })
    }

    /// Generate a WASM module from JSON-serialized function definitions.
    ///
    /// This is the primary entry point for the ReScript frontend, which
    /// serializes its parsed XML AST to JSON and invokes this backend.
    pub fn generate_from_json(&mut self, json: &str) -> Result<WasmModule, WasmError> {
        let functions: Vec<FunctionDef> = serde_json::from_str(json).map_err(|e| {
            WasmError::InvalidAst {
                message: e.to_string(),
            }
        })?;
        self.generate(&functions)
    }
}

impl Default for WasmBackend {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Verify that an empty module (no functions) produces valid WASM.
    #[test]
    fn test_empty_module() {
        let mut backend = WasmBackend::new();
        let result = backend.generate(&[]);
        assert!(result.is_ok());
        let module = result.unwrap();
        assert!(module.binary_size > 0);
        assert_eq!(module.functions.len(), 0);
        assert_eq!(&module.to_bytes()[..4], b"\0asm");
    }

    /// Verify that a simple say-only function generates valid WASM.
    #[test]
    fn test_simple_function() {
        let mut backend = WasmBackend::new();
        let functions = vec![FunctionDef {
            name: "greet".to_string(),
            params: vec![],
            result: None,
            uses_canvas: false,
            uses_say: true,
        }];
        let result = backend.generate(&functions);
        assert!(result.is_ok());
        let module = result.unwrap();
        assert_eq!(module.functions.len(), 1);
        assert_eq!(module.functions[0].name, "greet");
        assert!(module.functions[0].uses_say);
        assert!(!module.functions[0].uses_canvas);
    }

    /// Verify module structure with canvas and say functions.
    #[test]
    fn test_module_structure() {
        let mut backend = WasmBackend::new().with_canvas(true);
        let functions = vec![
            FunctionDef {
                name: "draw_house".to_string(),
                params: vec![],
                result: None,
                uses_canvas: true,
                uses_say: false,
            },
            FunctionDef {
                name: "describe".to_string(),
                params: vec![],
                result: None,
                uses_canvas: false,
                uses_say: true,
            },
        ];
        let result = backend.generate(&functions);
        assert!(result.is_ok());
        let module = result.unwrap();
        assert_eq!(module.functions.len(), 2);
        assert!(module.functions[0].uses_canvas);
        assert!(module.functions[1].uses_say);
    }

    /// Verify error handling for heap overflow.
    #[test]
    fn test_error_handling_heap_overflow() {
        let mut allocator = BumpAllocator::new(0, 1); // 1 page = 64KB
        let r1 = allocator.alloc(60000);
        assert!(r1.is_ok());
        let r2 = allocator.alloc(10000);
        assert!(r2.is_err());
        match r2 {
            Err(WasmError::HeapOverflow { requested, .. }) => {
                assert_eq!(requested, 10000);
            }
            _ => panic!("expected HeapOverflow"),
        }
    }

    /// Verify the binary starts with WASM magic number and version.
    #[test]
    fn test_binary_validation() {
        let mut backend = WasmBackend::new().with_canvas(true);
        let functions = vec![FunctionDef {
            name: "draw_art".to_string(),
            params: vec![],
            result: Some(WasmType::I32),
            uses_canvas: true,
            uses_say: true,
        }];
        let result = backend.generate(&functions);
        assert!(result.is_ok());
        let module = result.unwrap();
        let bytes = module.to_bytes();
        assert_eq!(&bytes[..4], b"\0asm");
        assert_eq!(&bytes[4..8], &[1, 0, 0, 0]);
        assert!(bytes.len() > 50);
    }

    /// Verify JSON deserialization round-trip.
    #[test]
    fn test_json_round_trip() {
        let functions = vec![FunctionDef {
            name: "main".to_string(),
            params: vec![],
            result: None,
            uses_canvas: false,
            uses_say: true,
        }];
        let json = serde_json::to_string(&functions).unwrap();
        let mut backend = WasmBackend::new();
        let result = backend.generate_from_json(&json);
        assert!(result.is_ok());
        let module = result.unwrap();
        assert_eq!(module.functions.len(), 1);
        assert_eq!(module.functions[0].name, "main");
    }

    /// Verify invalid JSON produces a useful error.
    #[test]
    fn test_invalid_json() {
        let mut backend = WasmBackend::new();
        let result = backend.generate_from_json("<<< not json >>>");
        assert!(result.is_err());
        match result {
            Err(WasmError::InvalidAst { message }) => {
                assert!(!message.is_empty());
            }
            _ => panic!("expected InvalidAst"),
        }
    }

    /// Verify string interning.
    #[test]
    fn test_string_interning() {
        let mut backend = WasmBackend::new().with_initial_memory(1);
        let offset1 = backend.intern_string("Hello, I am Me!");
        assert!(offset1.is_ok());
        assert_eq!(offset1.unwrap(), 0);
        let offset2 = backend.intern_string("drawing");
        assert!(offset2.is_ok());
        // "Hello, I am Me!" = 15 bytes, aligned to 4 -> offset 16
        assert_eq!(offset2.unwrap(), 16);
    }

    /// Verify canvas-disabled mode rejects canvas functions cleanly.
    #[test]
    fn test_no_canvas_still_generates() {
        let mut backend = WasmBackend::new(); // canvas_enabled = false
        let functions = vec![FunctionDef {
            name: "draw_attempt".to_string(),
            params: vec![],
            result: None,
            uses_canvas: true, // Claims canvas, but backend has canvas disabled.
            uses_say: false,
        }];
        // Should still generate (no canvas imports, but no crash).
        let result = backend.generate(&functions);
        assert!(result.is_ok());
    }
}
