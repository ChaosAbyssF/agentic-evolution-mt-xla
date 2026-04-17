#include <musa_runtime.h>

#include <cmath>
#include <cstdio>
#include <cstdint>
#include <vector>

#include "musa_ext/kernels/math/musa_addn_kernel.mu"

static constexpr int kNumInputs = 8;
static constexpr int kNumElements = 1 << 24;  // 16,777,216
static constexpr int kWarmupIters = 30;
static constexpr int kMeasureIters = 200;

static void CheckMusa(musaError_t err, const char* call) {
  if (err != musaSuccess) {
    std::fprintf(stderr, "MUSA call failed: %s (%d, %s)\n", call,
                 static_cast<int>(err), musaGetErrorString(err));
    std::exit(1);
  }
}

int main() {
  std::vector<std::vector<float>> h_inputs(kNumInputs,
                                            std::vector<float>(kNumElements));
  for (int j = 0; j < kNumInputs; ++j) {
    for (int i = 0; i < kNumElements; ++i) {
      h_inputs[j][i] = static_cast<float>((i % 2048) * 0.0005f + j * 0.125f);
    }
  }

  std::vector<float*> d_inputs(kNumInputs, nullptr);
  float* d_output = nullptr;
  for (int j = 0; j < kNumInputs; ++j) {
    CheckMusa(musaMalloc(reinterpret_cast<void**>(&d_inputs[j]),
                         sizeof(float) * kNumElements),
              "musaMalloc(input)");
    CheckMusa(
        musaMemcpy(d_inputs[j], h_inputs[j].data(), sizeof(float) * kNumElements,
                   musaMemcpyHostToDevice),
        "musaMemcpy(input H2D)");
  }
  CheckMusa(musaMalloc(reinterpret_cast<void**>(&d_output),
                       sizeof(float) * kNumElements),
            "musaMalloc(output)");

  InlinePointers inline_inputs;
  for (int j = 0; j < kNumInputs; ++j) {
    inline_inputs.ptrs[j] = d_inputs[j];
  }

  for (int i = 0; i < kWarmupIters; ++i) {
    LaunchAddNKernelFloat(nullptr, inline_inputs, d_output, kNumInputs,
                          kNumElements, 0);
  }
  CheckMusa(musaDeviceSynchronize(), "musaDeviceSynchronize(warmup)");

  musaEvent_t start, stop;
  CheckMusa(musaEventCreate(&start), "musaEventCreate(start)");
  CheckMusa(musaEventCreate(&stop), "musaEventCreate(stop)");

  CheckMusa(musaEventRecord(start, 0), "musaEventRecord(start)");
  for (int i = 0; i < kMeasureIters; ++i) {
    LaunchAddNKernelFloat(nullptr, inline_inputs, d_output, kNumInputs,
                          kNumElements, 0);
  }
  CheckMusa(musaEventRecord(stop, 0), "musaEventRecord(stop)");
  CheckMusa(musaEventSynchronize(stop), "musaEventSynchronize(stop)");

  float total_ms = 0.0f;
  CheckMusa(musaEventElapsedTime(&total_ms, start, stop),
            "musaEventElapsedTime");

  std::vector<float> h_output(4096);
  CheckMusa(musaMemcpy(h_output.data(), d_output, sizeof(float) * h_output.size(),
                       musaMemcpyDeviceToHost),
            "musaMemcpy(output D2H)");

  double checksum = 0.0;
  for (float v : h_output) checksum += static_cast<double>(v);

  std::printf("checksum=%.10f\n", checksum);
  std::printf("Time: %.6f\n", total_ms / static_cast<float>(kMeasureIters));

  CheckMusa(musaEventDestroy(start), "musaEventDestroy(start)");
  CheckMusa(musaEventDestroy(stop), "musaEventDestroy(stop)");
  for (float* p : d_inputs) {
    CheckMusa(musaFree(p), "musaFree(input)");
  }
  CheckMusa(musaFree(d_output), "musaFree(output)");
  return 0;
}
