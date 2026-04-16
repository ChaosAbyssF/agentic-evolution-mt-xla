# XLA Custom Call Flow for MUSA Whole-Model Optimization

The whole point of this workflow is to make standalone operator optimizations
matter for end-to-end TensorFlow 2.15 inference.

That requires routing optimized implementations through XLA custom calls.

## Why This Matters

Without custom-call integration, the optimized operator usually stays outside
the real TF2.15 + XLA execution path. You may have a faster local kernel, but
the whole network will still run the old lowering.

The required chain is:

1. Optimize the operator implementation
2. Match the target HLO pattern
3. Rewrite it to a `custom-call`
4. Register and bridge the custom call
5. Let GPU runtime resolve the target
6. Rebuild the relevant XLA/JIT targets
7. Re-run the whole model

## Main Files and Roles

### `third_party/xla/xla/service/gpu/runtime/custom_call.cc`

This is the GPU runtime dispatcher for classic XLA GPU custom calls.

It ultimately:

- looks up `call_target_name`
- resolves it through `CustomCallTargetRegistry`
- marshals memref buffers
- invokes the registered target with the expected calling convention

If the target is not registered or not reachable from the runtime, the whole
integration fails even if the rewriter is correct.

### `third_party/xla/xla/service/gpu/mtgpu_compiler.cc`

This is the MTGPU compiler pass insertion point.

Use it to place MUSA-specific HLO passes that transform recognized patterns into
custom calls. The rewriter must run in the correct pipeline stage, otherwise the
pattern may never match or may be optimized away before the rewrite fires.

### `third_party/xla/xla/service/gpu/musa_layer_norm_rewriter.h`

Treat this as the canonical example.

It shows the expected structure for:

- recognizing a fused pattern
- guarding the rewrite with shape/layout constraints
- lowering the pattern to a MUSA-specific custom call path

### `third_party/xla/xla/service/gpu/musa_layer_norm_rewriter_test.cc`

Use this to define the rewriter test style for any future op.

The test should prove:

- the HLO pattern is recognized
- the output HLO contains the expected custom call
- unsupported shapes or forms do not rewrite accidentally

### `third_party/xla/xla/service/gpu/musa_fusion_custom_calls.cc/.h`

This is the bridge layer between rewritten HLO custom calls and the actual
runtime targets.

Use it to define:

- custom call target names
- backend_config wiring
- shape or attribute helpers
- registration and dispatch helpers

### `third_party/xla/xla/service/gpu/musa_fusion_custom_calls_test.cc`

Use this to prove the custom-call bridge is wired correctly and preserves the
expected contract between the rewrite side and runtime side.

### `third_party/xla/xla/service/gpu/BUILD`

This must pull the rewriter, bridge, and tests into the right GPU/XLA targets.

Typical mistakes:

- new source file exists but is not linked into `gpu_plugin`
- test target added but the implementation library is not
- runtime/rewriter split does not match BUILD deps

### `tensorflow/compiler/jit/BUILD`

This is the TensorFlow JIT side of the integration.

For the MUSA path, the JIT targets need to keep pulling in the GPU plugin so the
rewriter and runtime registration actually land in the compiled TensorFlow path.

## LayerNorm Template for New Operators

When onboarding a new hotspot operator, use LayerNorm as the template.

### Step 1

Get a standalone optimized implementation working first.

### Step 2

Create a `musa_<op>_rewriter` modeled on LayerNorm:

- same style of pattern matching
- same level of shape/layout guarding
- same rewrite-to-custom-call strategy

### Step 3

Register the new custom call in `musa_fusion_custom_calls.cc/.h`.

### Step 4

Insert the pass into the MTGPU compiler pipeline.

### Step 5

Update BUILD targets so the code is actually linked.

### Step 6

Add rewriter and custom-call tests.

### Step 7

Verify the real whole-model path now hits the custom call and improves latency.

## Acceptance Checklist

For any operator, the integration is only complete when all are true:

- optimized implementation is correct
- rewriter test passes
- custom-call bridge test passes
- BUILD graph compiles
- runtime resolves the call target
- whole-model latency improves in the user-provided target container
