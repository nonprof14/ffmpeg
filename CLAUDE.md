# FFmpeg Codebase Guide for AI Assistants

This document provides a comprehensive overview of the FFmpeg codebase structure, development workflows, and conventions specifically designed for AI assistants working with this repository.

## Table of Contents

1. [Project Overview](#project-overview)
2. [Repository Structure](#repository-structure)
3. [Library Architecture](#library-architecture)
4. [Build System](#build-system)
5. [Development Workflow](#development-workflow)
6. [Testing Infrastructure](#testing-infrastructure)
7. [Coding Conventions](#coding-conventions)
8. [Common Operations](#common-operations)
9. [Key Concepts](#key-concepts)
10. [Resources](#resources)

---

## Project Overview

FFmpeg is a complete, cross-platform solution to record, convert, and stream audio and video. It consists of:

- **7 Core Libraries**: libavcodec, libavformat, libavutil, libavfilter, libavdevice, libswresample, libswscale
- **3 Main Tools**: ffmpeg (transcoding), ffplay (player), ffprobe (analyzer)
- **200+ Codecs**: Audio and video encoding/decoding implementations
- **100+ Formats**: Container format muxers and demuxers
- **500+ Filters**: Audio and video processing filters

### License

- **Primarily LGPL v2.1+** with optional GPL v2+ components
- Check `LICENSE.md` and `COPYING.*` files for details
- Some components require explicit enabling via `--enable-gpl`

### Contribution Model

**IMPORTANT**: This is a fork/mirror. Upstream FFmpeg uses:
- **Mailing list**: ffmpeg-devel@ffmpeg.org (primary review process)
- **git send-email**: For submitting patches
- **GitHub Pull Requests**: NOT part of upstream's review process

---

## Repository Structure

```
ffmpeg/
├── libavcodec/         # Codec library (1,700+ files)
├── libavformat/        # Container formats & I/O (700+ files)
├── libavutil/          # Utility library (270+ files)
├── libavfilter/        # Audio/video filtering (650+ files)
├── libavdevice/        # Device capture/playback (75+ files)
├── libswscale/         # Color conversion & scaling (50+ files)
├── libswresample/      # Audio resampling (25+ files)
├── fftools/            # Command-line tools (ffmpeg, ffplay, ffprobe)
├── doc/                # Documentation (Texinfo format)
├── tests/              # Testing infrastructure (FATE)
│   ├── fate/           # Test definitions
│   ├── ref/            # Reference outputs
│   ├── checkasm/       # Assembly/DSP tests
│   └── api/            # API tests
├── compat/             # Platform compatibility layer
├── tools/              # Utility programs and scripts
├── presets/            # Encoding presets
├── ffbuild/            # Build system infrastructure
├── configure*          # Configuration script (300KB)
├── Makefile            # Main build orchestrator
└── MAINTAINERS         # Component maintainers list
```

### Directory Sizes (by file count)

- **libavcodec**: 1,709 files (encoders, decoders, parsers, bitstream filters)
- **libavformat**: 696 files (demuxers, muxers, protocols)
- **libavfilter**: 645 files (audio/video filters, filter graphs)
- **libavutil**: 268 files (utilities, crypto, hardware contexts)
- **tests**: 286 files (FATE framework, reference data)
- **doc**: 84 files (user docs, API docs, examples)

---

## Library Architecture

### Dependency Hierarchy

```
libavutil (foundation - no dependencies)
    ↓
libavcodec, libavfilter, libswscale, libswresample
    ↓
libavformat (depends on libavcodec, libavutil)
    ↓
libavdevice (depends on libavformat, libavcodec, libavutil)
    ↓
ffmpeg, ffplay, ffprobe (depend on all libraries)
```

### Core Libraries

#### 1. libavutil (Utility Library)

**Location**: `libavutil/`

**Purpose**: Foundation library providing utilities used by all other components.

**Key Components**:
- Memory management: `mem.c`, `buffer.c`
- Math utilities: `mathematics.c`, `rational.c`, `integer.c`
- Cryptography: `aes.c`, `sha.c`, `md5.c`, `hash.c`
- Data structures: `dict.c`, `tree.c`, `fifo.c`, `heap.c`
- Pixel/frame handling: `pixdesc.c`, `imgutils.c`, `frame.c`
- Hardware contexts: `hwcontext_*.c` (CUDA, VAAPI, D3D12, Vulkan, etc.)
- Options system: `opt.c`
- String utilities: `bprint.c`, `base64.c`

**Key Headers**:
- `avutil.h` - Main API
- `pixfmt.h` - Pixel formats
- `samplefmt.h` - Audio sample formats
- `channel_layout.h` - Audio channel layouts
- `frame.h` - Audio/video frame structures

#### 2. libavcodec (Codec Library)

**Location**: `libavcodec/`

**Purpose**: Encoding and decoding audio/video codecs.

**Key Components**:
- Codec management: `allcodecs.c`, `codec.c`, `codec_desc.c`
- Encode/decode infrastructure: `encode.c`, `decode.c`
- Packet handling: `packet.c`, `packet.h`
- Bitstream filters: `bsf.c`, `bsf/` directory
- Parsers: `parser.c`
- Hardware acceleration: `hwaccel.c`, `hwcontext_*.c`

**Architecture-Specific Optimizations**:
- `x86/` - x86/x64 SIMD (SSE, AVX) - `.asm` files
- `arm/` - ARM NEON - `.S` files
- `aarch64/` - ARM64 optimizations
- `mips/`, `loongarch/`, `ppc/`, `riscv/`, `wasm/` - Other architectures

**Codec Organization Pattern**:
```
xxxdec.c         # Decoder implementation
xxxenc.c         # Encoder implementation
xxxdata.c/.h     # Shared data tables
xxx/             # Complex codecs get subdirectories (hevc/, vvc/, aac/)
```

#### 3. libavformat (Format/Container Library)

**Location**: `libavformat/`

**Purpose**: Muxing, demuxing, and I/O for container formats.

**Key Components**:
- Format management: `allformats.c`, `mux.c`, `demux.c`
- I/O abstraction: `avio.c`, `aviobuf.c`, `url.c`
- Protocol implementations: HTTP, FTP, RTMP, RTP, file I/O
- Metadata handling: `id3v2.c`, `metadata.c`
- Format-specific: `mov.c`, `matroska*.c`, `mpegts.c`, `avi*.c`

**Common Patterns**:
- Demuxers: `xxxdec.c` (e.g., `matroskadec.c`)
- Muxers: `xxxenc.c` (e.g., `matroskaenc.c`)
- Shared code: `xxx.c`/`xxx.h`

#### 4. libavfilter (Filtering Library)

**Location**: `libavfilter/`

**Purpose**: Graph-based audio/video processing.

**Key Components**:
- Filter infrastructure: `avfilter.c`, `graph.c`, `graphparser.c`
- Filter registry: `allfilters.c`
- Buffer management: `buffersrc.c`, `buffersink.c`
- Format negotiation: `formats.c`

**Filter Naming Convention**:
- `af_*.c` - Audio filters (e.g., `af_volume.c`)
- `vf_*.c` - Video filters (e.g., `vf_scale.c`)
- `asrc_*.c` - Audio sources (e.g., `asrc_sine.c`)
- `vsrc_*.c` - Video sources (e.g., `vsrc_color.c`)

**GPU Implementations**:
- `cuda/` - NVIDIA CUDA
- `opencl/` - OpenCL
- `vulkan/` - Vulkan Compute
- `metal/` - Apple Metal
- Subdirectory: `dnn/` - Deep Neural Network integration (TensorFlow, OpenVINO, Torch)

#### 5. libswscale (Scaling Library)

**Location**: `libswscale/`

**Purpose**: Color conversion, image scaling, and format conversion.

**Features**:
- RGB ↔ YUV conversion
- Bilinear, bicubic, Lanczos scaling
- SIMD optimizations: `x86/`, `arm/`, `aarch64/`, `ppc/`, `riscv/`

#### 6. libswresample (Resampling Library)

**Location**: `libswresample/`

**Purpose**: Audio resampling, mixing, and format conversion.

**Features**:
- Sample rate conversion
- Channel layout conversion
- Audio mixing
- SIMD optimizations: `x86/`, `arm/`

#### 7. libavdevice (Device Library)

**Location**: `libavdevice/`

**Purpose**: Hardware device input/output abstraction.

**Devices**:
- Audio: ALSA, PulseAudio, sndio, CoreAudio
- Video capture: v4l2, GDI, DirectShow, Android Camera
- Display output: framebuffer, X11, SDL, OpenGL
- Professional: DeckLink hardware

---

## Build System

### Configuration

**Script**: `configure` (300KB POSIX shell script)

**Purpose**:
- Detect system capabilities
- Check for dependencies
- Generate `ffbuild/config.mak` and `config.h`
- Support 1000+ options

**Common Options**:
```bash
./configure --help                    # Show all options
./configure --list-decoders           # List available decoders
./configure --list-encoders           # List available encoders
./configure --disable-static          # Build shared libraries only
./configure --enable-gpl              # Enable GPL components
./configure --enable-nonfree          # Enable non-free components
./configure --prefix=/usr/local       # Install prefix
./configure --enable-debug            # Enable debugging symbols
```

**Out-of-tree builds** (recommended):
```bash
mkdir build && cd build
/path/to/ffmpeg/configure [options]
make
```

### Makefile Structure

**Root Makefile**: `Makefile` (orchestrates entire build)

**Key Build Files**:
- `ffbuild/config.mak` - Generated configuration (DO NOT EDIT)
- `ffbuild/common.mak` - Common build rules and compiler flags
- `ffbuild/library.mak` - Library-specific build rules
- `ffbuild/arch.mak` - Architecture detection

**Per-Library Makefiles**:
```
libavcodec/Makefile
libavformat/Makefile
libavutil/Makefile
libavfilter/Makefile
libavdevice/Makefile
libswscale/Makefile
libswresample/Makefile
fftools/Makefile
doc/Makefile
tests/Makefile
```

**Makefile Pattern**:
```makefile
NAME = avcodec                        # Library name
DESC = FFmpeg codec library           # Description
HEADERS = avcodec.h packet.h ...      # Public headers
OBJS = allcodecs.o codec.o ...        # Always compiled
OBJS-$(CONFIG_H264_DECODER) += h264dec.o  # Conditional
```

### Build Commands

```bash
make                    # Build all configured components
make alltools           # Build all tools (in tools/)
make examples           # Build example programs (doc/examples/)
make testprogs          # Build test programs
make fate               # Run FATE test suite
make install            # Install to PREFIX
make clean              # Remove build artifacts
make distclean          # Remove all generated files
```

### Compilation Rules

**From `ffbuild/common.mak`**:

```makefile
COMPILE_C       # Compile .c → .o
COMPILE_CXX     # Compile .cpp → .o
COMPILE_S       # Compile .S → .o (ARM assembly)
COMPILE_X86ASM  # Compile .asm → .o (x86 NASM)
COMPILE_NVCC    # Compile .cu → .ptx (CUDA)
COMPILE_MMI     # Compile with MMI SIMD flags
COMPILE_MSA     # Compile with MSA SIMD flags
COMPILE_LSX     # Compile with LSX SIMD flags
COMPILE_LASX    # Compile with LASX SIMD flags
```

**Architecture Dispatch Pattern**:
1. Portable C implementation (always present)
2. SIMD assembly implementations (architecture-specific)
3. `*_init.c` files dispatch to best available implementation at runtime

**Example** (AC3 DSP):
```
libavcodec/ac3dsp.c              # Portable C
libavcodec/x86/ac3dsp.asm        # x86 SIMD
libavcodec/x86/ac3dsp_init.c     # x86 dispatcher
libavcodec/arm/ac3dsp_arm.S      # ARM NEON
libavcodec/arm/ac3dsp_init_arm.c # ARM dispatcher
```

---

## Development Workflow

### Code Organization Principles

1. **Modularity**: Each library can be built and used independently
2. **Portability**: Fallbacks for missing system features (see `compat/`)
3. **Optimization**: SIMD implementations alongside portable C code
4. **Configuration-Driven**: Conditional compilation via `CONFIG_*` variables
5. **Versioning**: Each library has independent version numbers

### Coding Style

**General Guidelines**:
- K&R-style bracing
- 4-space indentation (no tabs in C code)
- `snake_case` for functions and variables
- `CamelCase` for structures/types (less common)
- Max line length: ~80 characters (flexible)

**Naming Conventions**:
- Public API: `av_*`, `avcodec_*`, `avformat_*`, etc.
- Internal functions: `ff_*` prefix
- Static functions: No prefix requirement
- Architecture-specific: `ff_xxx_sse2`, `ff_xxx_neon`

**Example**:
```c
// Public API (in header)
int avcodec_open2(AVCodecContext *avctx, const AVCodec *codec,
                  AVDictionary **options);

// Internal API (internal.h)
int ff_thread_can_start_frame(AVCodecContext *avctx);

// Static function
static int find_stream_info(AVFormatContext *s);
```

### File Organization

**Header Files**:
- `avcodec.h`, `avformat.h`, etc. - Public API (installed)
- `xxx_internal.h` or `internal.h` - Internal API (not installed)
- `xxx_data.h` - Data tables and constants

**Source Files**:
- `xxx.c` - Main implementation
- `xxxdec.c` - Decoder
- `xxxenc.c` - Encoder
- `xxx_parser.c` - Parser
- `xxx_bsf.c` - Bitstream filter

**Platform-Specific**:
- `x86/*.asm` - x86/x64 assembly (NASM/YASM)
- `arm/*.S` - ARM assembly (GAS syntax)
- `*_template.c` - C templates (preprocessor-based)

### Adding New Components

#### Adding a New Codec

1. Create decoder/encoder file: `libavcodec/xxxdec.c` or `libavcodec/xxxenc.c`
2. Add entry to `libavcodec/allcodecs.c`
3. Add `OBJS-$(CONFIG_XXX_DECODER)` to `libavcodec/Makefile`
4. Update `configure` with new codec option
5. Add documentation to `doc/codecs.texi`

#### Adding a New Filter

1. Create filter file: `libavfilter/vf_xxx.c` or `libavfilter/af_xxx.c`
2. Add entry to `libavfilter/allfilters.c`
3. Add `OBJS-$(CONFIG_XXX_FILTER)` to `libavfilter/Makefile`
4. Update `configure` with new filter option
5. Add documentation to `doc/filters.texi`

#### Adding a New Format

1. Create demuxer/muxer: `libavformat/xxxdec.c` or `libavformat/xxxenc.c`
2. Add entry to `libavformat/allformats.c`
3. Add `OBJS-$(CONFIG_XXX_DEMUXER)` to `libavformat/Makefile`
4. Update `configure`
5. Add documentation to `doc/demuxers.texi` or `doc/muxers.texi`

### Version Management

Each library maintains independent versions:

**Version Files**:
- `libavcodec/version.h` - Minor/micro version
- `libavcodec/version_major.h` - Major version
- Pattern: `#define LIBAVCODEC_VERSION_MAJOR 61`

**Generated Files**:
- `libavutil/ffversion.h` - Git revision info (auto-generated)
- `.version` - Version tracking marker

---

## Testing Infrastructure

### FATE (FFmpeg Automated Testing Environment)

**Location**: `tests/`

**Purpose**: Comprehensive regression testing framework

### Test Structure

```
tests/
├── fate.sh                 # Main FATE script
├── fate-run.sh            # Test runner (24KB)
├── Makefile               # Test build rules
├── fate/                  # Test definitions
│   ├── *.mak             # Test case definitions
│   ├── maps/             # Mapping files
│   └── filtergraphs/     # Filter graph tests
├── ref/                   # Reference outputs
│   ├── fate/             # Expected outputs
│   ├── acodec/           # Audio codec refs
│   ├── vsynth/           # Video synthesis refs
│   └── seek/             # Seeking tests
├── checkasm/              # Assembly/DSP verification
│   ├── checkasm.c        # Test harness
│   └── *.c               # Per-codec DSP tests
└── api/                   # API-level tests
    └── api-*.c           # Individual API tests
```

### Running Tests

```bash
# Run all FATE tests
make fate

# Run specific test
make fate-h264-conformance-high

# Run test suite category
make fate-aac
make fate-h264
make fate-vp9

# Generate reference files (maintainer only)
make fate GEN=1

# Run with specific threads
make fate THREADS=4
```

### Writing Tests

FATE tests are defined in `.mak` files under `tests/fate/`:

**Example** (`tests/fate/aac.mak`):
```makefile
FATE_AAC += fate-aac-decoder-main
fate-aac-decoder-main: CMD = pcm -i $(TARGET_SAMPLES)/aac/main.aac
fate-aac-decoder-main: REF = $(SAMPLES)/aac/main.pcm
fate-aac-decoder-main: CMP = stddev
fate-aac-decoder-main: FUZZ = 0.05
```

### checkasm (Assembly Verification)

**Purpose**: Verify SIMD implementations match C reference

**Location**: `tests/checkasm/`

**Usage**:
```bash
# Build checkasm
make tests/checkasm/checkasm

# Run all tests
tests/checkasm/checkasm

# Run specific test
tests/checkasm/checkasm --test=h264dsp

# Benchmark
tests/checkasm/checkasm --bench
```

---

## Coding Conventions

### API Design

1. **Return Values**:
   - Success: 0 or positive values
   - Errors: Negative `AVERROR()` codes
   - Use: `AVERROR(EINVAL)`, `AVERROR(ENOMEM)`, `AVERROR_EOF`

2. **Memory Management**:
   - Use `av_malloc()`, `av_free()` (libavutil)
   - Use `av_buffer_*()` for reference-counted buffers
   - Always check allocation results

3. **Structures**:
   - Opaque to users when possible
   - Use accessor functions for public APIs
   - Keep padding for ABI compatibility

4. **Threading**:
   - Thread-safe by default for decode/encode
   - Frame-level or slice-level threading
   - Use `ff_thread_*()` APIs

### Documentation

**Doxygen Comments**:
```c
/**
 * @brief Brief description
 *
 * Detailed description of function behavior.
 *
 * @param avctx  codec context
 * @param frame  destination frame
 * @return 0 on success, negative AVERROR on error
 */
int avcodec_receive_frame(AVCodecContext *avctx, AVFrame *frame);
```

**Texinfo Documentation**:
- User docs: `doc/*.texi`
- Large and comprehensive: `doc/filters.texi` is 941KB!

### Optimization Guidelines

**From `doc/optimization.txt`**:

1. **Measure First**: Use `time`, `perf`, or `checkasm --bench`
2. **Profile**: Identify hotspots before optimizing
3. **SIMD**: Write portable C first, then add SIMD
4. **Alignment**: Ensure data alignment for SIMD
5. **Cache**: Consider cache-friendly data structures

**SIMD Implementation Steps**:
1. Write portable C implementation
2. Add SIMD version (`.asm` or `.S`)
3. Add init/dispatcher code (`*_init.c`)
4. Add checkasm test to verify correctness
5. Update Makefile with architecture conditions

---

## Common Operations

### Building FFmpeg

```bash
# Standard build
./configure --enable-gpl --enable-version3
make -j$(nproc)
sudo make install

# Debug build
./configure --enable-debug --disable-optimizations --disable-stripping
make

# Cross-compile for Windows (from Linux)
./configure --arch=x86_64 --target-os=mingw32 --cross-prefix=x86_64-w64-mingw32-
make
```

### Searching the Codebase

```bash
# Find codec implementation
git grep -l "AVCodec.*h264"

# Find filter by name
find libavfilter -name "*scale*"

# Find API usage
git grep "avcodec_send_packet"

# Find TODOs
git grep -n "TODO\|FIXME\|XXX"
```

### Understanding a Codec

1. **Find codec registration**: `libavcodec/allcodecs.c`
2. **Locate implementation**: `libavcodec/xxxdec.c` or `libavcodec/xxxenc.c`
3. **Check for subdirectory**: Complex codecs have own directories (e.g., `hevc/`, `vvc/`)
4. **Find hardware acceleration**: `libavcodec/xxx_hwaccel.c` or `hwaccel_xxx.c`
5. **Check tests**: `tests/fate/*.mak` and `tests/checkasm/xxx.c`
6. **Read documentation**: `doc/codecs.texi`, `doc/encoders.texi`, `doc/decoders.texi`

### Debugging

```bash
# Enable debug logging
export AV_LOG_FORCE_NOCOLOR=1
ffmpeg -v debug -i input.mp4 output.mp4

# Trace level (very verbose)
ffmpeg -v trace -i input.mp4 output.mp4

# Report to file
ffmpeg -report -i input.mp4 output.mp4  # Creates ffmpeg-*.log

# Use gdb
gdb --args ffmpeg -i input.mp4 output.mp4
```

### Profiling

```bash
# perf (Linux)
perf record ffmpeg -i input.mp4 output.mp4
perf report

# Valgrind (memory)
valgrind --leak-check=full ffmpeg -i input.mp4 output.mp4

# Callgrind (profiling)
valgrind --tool=callgrind ffmpeg -i input.mp4 output.mp4
kcachegrind callgrind.out.*
```

---

## Key Concepts

### 1. AVCodecContext

Central structure for encoding/decoding:
```c
AVCodecContext *avctx = avcodec_alloc_context3(codec);
avctx->width = 1920;
avctx->height = 1080;
avctx->pix_fmt = AV_PIX_FMT_YUV420P;
avcodec_open2(avctx, codec, NULL);
```

### 2. AVFrame

Container for decoded audio/video:
```c
AVFrame *frame = av_frame_alloc();
// Decoder fills frame
avcodec_receive_frame(avctx, frame);
// Process frame
av_frame_free(&frame);
```

### 3. AVPacket

Container for encoded data:
```c
AVPacket *pkt = av_packet_alloc();
av_read_frame(fmt_ctx, pkt);  // Read from input
avcodec_send_packet(avctx, pkt);  // Send to decoder
av_packet_free(&pkt);
```

### 4. AVFormatContext

Container format context:
```c
AVFormatContext *fmt_ctx = NULL;
avformat_open_input(&fmt_ctx, "input.mp4", NULL, NULL);
avformat_find_stream_info(fmt_ctx, NULL);
// Use streams: fmt_ctx->streams[i]
avformat_close_input(&fmt_ctx);
```

### 5. AVFilterGraph

Filter graph for processing:
```c
AVFilterGraph *graph = avfilter_graph_alloc();
// Build graph with inputs/outputs
avfilter_graph_config(graph, NULL);
// Process frames through graph
avfilter_graph_free(&graph);
```

### 6. Hardware Acceleration

Multiple backends:
- **VAAPI**: Linux (Intel/AMD/NVIDIA)
- **VDPAU**: Linux (NVIDIA)
- **D3D11VA**: Windows
- **DXVA2**: Windows
- **VideoToolbox**: macOS/iOS
- **QSV**: Intel Quick Sync
- **NVENC/NVDEC**: NVIDIA hardware
- **AMF**: AMD hardware
- **MediaCodec**: Android
- **V4L2 M2M**: Linux (embedded)

**Usage**:
```c
AVBufferRef *hw_device_ctx = NULL;
av_hwdevice_ctx_create(&hw_device_ctx, AV_HWDEVICE_TYPE_VAAPI,
                       "/dev/dri/renderD128", NULL, 0);
avctx->hw_device_ctx = av_buffer_ref(hw_device_ctx);
```

### 7. Threading

**Frame Threading**: Each frame decoded independently
**Slice Threading**: Frame divided into slices

```c
avctx->thread_count = 4;          // Number of threads
avctx->thread_type = FF_THREAD_FRAME | FF_THREAD_SLICE;
```

### 8. Configuration System

**CONFIG_* Variables** (generated by configure):
```c
#if CONFIG_H264_DECODER
    register_decoder(&ff_h264_decoder);
#endif
```

**Makefiles use these for conditional compilation**:
```makefile
OBJS-$(CONFIG_H264_DECODER) += h264dec.o h264_cabac.o h264_cavlc.o
```

---

## Resources

### Documentation

- **Online**: https://ffmpeg.org/documentation.html
- **Local**: `doc/*.texi` files
- **API**: `doc/Doxyfile` (generate with `make apidoc`)
- **Examples**: `doc/examples/*.c` (28 example programs)

### Important Files

- `README.md` - Project overview
- `CONTRIBUTING.md` - Contribution guidelines (upstream mailing list)
- `INSTALL.md` - Build instructions
- `MAINTAINERS` - Component maintainers
- `LICENSE.md` - Licensing information
- `Changelog` - Version history
- `RELEASE` - Current version number

### Key Documentation Files

- `doc/developer.texi` - Developer guide
- `doc/fate.texi` - FATE testing guide
- `doc/optimization.txt` - Optimization techniques
- `doc/filter_design.txt` - Filter design guide
- `doc/multithreading.txt` - Threading documentation
- `doc/build_system.txt` - Build system details

### Community

- **Mailing Lists**: https://ffmpeg.org/contact.html
  - ffmpeg-devel: Development discussions
  - ffmpeg-user: User support
- **IRC**: #ffmpeg on irc.libera.chat
- **Wiki**: https://trac.ffmpeg.org
- **Bug Tracker**: https://trac.ffmpeg.org

### Code Owners

See `.forgejo/CODEOWNERS` for component-specific reviewers (GitHub usernames).

---

## AI Assistant Guidelines

### Before Making Changes

1. **Read existing code** in the area you're modifying
2. **Check MAINTAINERS** file for component ownership
3. **Look for similar implementations** as reference
4. **Review tests** in `tests/fate/` and `tests/checkasm/`
5. **Check documentation** in `doc/` for user-facing changes

### When Adding Features

1. **Configuration option**: Add to `configure` script
2. **Conditional compilation**: Use `CONFIG_*` in Makefiles
3. **Documentation**: Update relevant `.texi` files
4. **Tests**: Add FATE tests or checkasm tests
5. **API stability**: Maintain backward compatibility

### When Fixing Bugs

1. **Reproduce the issue** if possible
2. **Check for similar bugs**: `git log --grep="bug description"`
3. **Add regression test**: Prevent future regressions
4. **Minimal changes**: Only fix the specific issue
5. **Document in commit message**: Clear description of problem and solution

### Code Review Checklist

- [ ] Follows coding style (K&R, 4-space indent)
- [ ] Uses appropriate `av_*` or `ff_*` prefixes
- [ ] Checks return values and handles errors
- [ ] Frees allocated memory (no leaks)
- [ ] Thread-safe if applicable
- [ ] SIMD has C fallback
- [ ] SIMD verified with checkasm
- [ ] Documented in appropriate `.texi` file
- [ ] FATE test added if applicable
- [ ] No warnings with `-Wall -Wextra`

### Common Pitfalls

1. **Don't break ABI**: Public structures must remain compatible
2. **Don't use C++**: Core libraries are C only (C++ allowed in wrappers)
3. **Don't use C99/C11 features** without compat layer
4. **Don't hardcode paths**: Use runtime detection
5. **Don't optimize prematurely**: Measure first
6. **Don't skip error checking**: Always check return values

---

## Appendix: Quick Reference

### Build Targets

```bash
make                # Build all
make alltools       # Build tools/
make examples       # Build doc/examples/
make testprogs      # Build test programs
make fate           # Run tests
make install        # Install
make clean          # Clean build artifacts
make distclean      # Clean everything
make apidoc         # Generate API documentation
```

### Environment Variables

```bash
PKG_CONFIG_PATH     # For finding dependencies
CC                  # C compiler
CXX                 # C++ compiler
AS                  # Assembler
LD                  # Linker
CFLAGS              # C compiler flags
LDFLAGS             # Linker flags
```

### Useful Configure Options

```bash
--help                        # Show all options
--list-*                      # List components
--enable-gpl                  # Enable GPL code
--enable-version3             # Enable LGPL v3/GPL v3
--enable-nonfree              # Enable non-free code
--enable-debug                # Debug symbols
--disable-optimizations       # Disable optimizations
--disable-stripping           # Keep symbols
--enable-shared               # Build shared libraries
--disable-static              # Don't build static libraries
--prefix=/usr/local           # Install prefix
--enable-cross-compile        # Cross-compilation mode
--arch=x86_64                 # Target architecture
--target-os=linux             # Target OS
```

### Common Error Codes

```c
AVERROR(EINVAL)     // Invalid argument
AVERROR(ENOMEM)     // Out of memory
AVERROR(EIO)        // I/O error
AVERROR_EOF         // End of file
AVERROR_UNKNOWN     // Unknown error
AVERROR_BUG         // Bug detected
AVERROR_EXTERNAL    // External library error
```

---

**Last Updated**: 2025-11-24
**FFmpeg Version**: See `RELEASE` file
**AI Assistant Version**: Claude Code

For questions or updates to this document, please consult the MAINTAINERS file or development mailing list.
