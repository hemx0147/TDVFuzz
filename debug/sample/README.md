# TDVF Debug Sample

This document describes how to run a sample debugging session of the TDVF-fuzz-hello target.

### 1. Activate kAFL environment
```
cd ~/tdvfuzz
make env
```

### 2. Build target & start short fuzzing session:
```
./scripts/build-n-fuzz.sh -b
```

### 3. Copy files & folders to workdir
```
export BUILD_DIR=$TDVFUZZ_ROOT/saved-workdirs/tdvf-hello-sample/target/tdvf-builddir
cp -r $KAFL_WORKDIR $TDVFUZZ_ROOT/saved-workdirs/tdvf-hello-sample
cp $BKC_ROOT/TDVF_hello.fd $TDVFUZZ_ROOT/saved-workdirs/tdvf-hello-sample/target
cp -r $TDVF_ROOT/Build $BUILD_DIR
```

The necessary files and directories are now located here:
- kAFL workdir: `$BKC_ROOT/saved-workdirs/tdvf-hello-sample`
- TDVF binary: `$BKC_ROOT/saved-workdirs/tdvf-hello-sample/target/TDVF.fd`
- TDVF build dir: `$BKC_ROOT/saved-workdirs/tdvf-hello-sample/target/tdvf-builddir`

### 4. Create debug symbol gdbscript
```
cd debug
./gen_symbol_offsets.sh -s sample/gdbscript $BUILD_DIR
```

### 5. Run debugging session
- run fuzzer in debug mode
    ```
    cd $BKC_ROOT
    ./fuzz.sh debug $LINUX_GUEST ../debug/sample/payloads/kasan_00186
    ```
- in another terminal window, start GDB & load symbols
    ```
    cd debug/sample
    gdb -x gdbscript
    ```

In GDB:
- attach to kAFL process
    ```
    target remote localhost:1234
    ```
- set hardware breakpoint to desired location, e.g. the `ProcessHobList()` function
    ```
    hbreak ProcessHobList
    ```
- execute target
    ```
    continue
    ```
    _Note:_ Due to a bug in qemu/GDB it might be the case that `run`/`continue`/`step` commands hang after being called. To end the hanging state, the command must be interrupted with `Ctrl+C`.
