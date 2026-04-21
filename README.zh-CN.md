# STFTKit

[English](README.md)

基于 Apple Accelerate 框架的 Swift 短时傅里叶变换（STFT）与逆变换（ISTFT）库，专为高性能音频信号处理设计。

## 功能特性

- 正向 STFT 与基于 overlap-add 重建的逆 STFT
- 单帧 FFT 处理，适用于实时场景
- 幅度/相位提取与重建
- Hann 与 Hamming 窗函数（支持对称/周期模式）
- 中心填充模式，实现边缘对齐分析
- 窗函数平方和归一化，实现完美重建
- 零外部依赖

## 系统要求

- Swift 5.9+
- iOS 16.0+ / macOS 13.0+

## 安装

在 `Package.swift` 中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/hohband/STFTKit.git", from: "1.0.0")
]
```

然后在目标的依赖中添加 `STFTKit`：

```swift
.target(name: "YourApp", dependencies: ["STFTKit"])
```

## 快速上手

```swift
import STFTKit

// 使用默认配置创建 STFT 实例
let stft = STFT()

// 准备音频信号（Float 单声道数组）
let signal: [Float] = /* 你的音频采样数据 */

// 正向变换 -> 频谱图
let spectrogram = stft.forward(signal)

// 逆变换 -> 重建信号
let reconstructed = stft.inverse(spectrogram)
```

## 配置

`STFTConfiguration` 用于控制分析参数：

```swift
let config = STFTConfiguration(
    fftSize: 2048,          // FFT 大小，必须为 2 的幂
    hopSize: 1024,          // 帧间步长
    window: .hann(periodic: true),  // 窗函数
    centerPadding: true     // 零填充信号居中
)
let stft = STFT(configuration: config)
```

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `fftSize` | 2048 | FFT 窗口大小（2 的幂） |
| `hopSize` | 1024 | 相邻帧之间的采样点数 |
| `window` | `.hann(periodic: true)` | 应用于每帧的窗函数 |
| `centerPadding` | `true` | 在信号两端补零，使帧中心对齐边缘 |

计算属性：
- `frequencyBins` — `fftSize / 2 + 1`（从直流到奈奎斯特频率）
- `packedBins` — `fftSize / 2`（Accelerate 实数 FFT 压缩格式）

## API 参考

### 全信号处理

#### `forward(_:)`

对整个信号执行 STFT，返回 `Spectrogram`。

```swift
let spectrogram = stft.forward(signal)
```

当 `centerPadding` 为 `true` 时，输入信号两端各补 `fftSize/2` 个零，使分析帧中心与信号边界对齐。

#### `inverse(_:)`

使用 overlap-add 加窗平方和归一化从 `Spectrogram` 重建时域信号。

```swift
let signal = stft.inverse(spectrogram)
```

### 幅度 / 相位

#### `magnitudes(from:)`

从频谱图中提取幅度值，返回展平的 `[Float]` 数组（帧数 × 频率窗，行优先）。

```swift
let mags = stft.magnitudes(from: spectrogram)
```

#### `spectrogram(fromMagnitudes:phases:frameCount:)`

从展平的幅度和相位数组构建 `Spectrogram`。

```swift
let spec = stft.spectrogram(fromMagnitudes: mags, phases: phases, frameCount: 100)
```

### 单帧处理

适用于实时或逐帧处理场景：

```swift
// 处理单帧
let spectrum: ComplexSpectrum = stft.processFrame(frame)

// 重建单帧
let samples: [Float] = stft.reconstructFrame(spectrum)
```

### 打包 / 解包辅助方法

在 Accelerate 的实数 FFT 压缩格式与完整的 `N/2+1` 频率窗表示之间转换：

```swift
// 压缩 -> 完整（直流 ... 奈奎斯特）
let fullBins: [ComplexBin] = stft.packedToFull(spectrum)

// 完整 -> 压缩
let packed: ComplexSpectrum = stft.fullToPacked(fullBins)
```

压缩格式布局：
- `real[0]` 存储直流分量
- `imag[0]` 存储奈奎斯特分量
- `real[k], imag[k]`（`1 <= k < N/2`）为复数频率窗

## 数据类型

### `Spectrogram`

复数频率窗的二维容器：

```swift
struct Spectrogram {
    var frames: [[ComplexBin]]
    var frameCount: Int         // 时间帧数
    var frequencyBins: Int      // 每帧频率窗数（fftSize/2 + 1）
    subscript(frame: Int, bin: Int) -> ComplexBin
}
```

### `ComplexSpectrum`

Accelerate 实数 FFT 的分离复数数组：

```swift
struct ComplexSpectrum {
    var real: [Float]
    var imag: [Float]
    var binCount: Int
}
```

### `ComplexBin`

频率窗的便捷类型别名：

```swift
typealias ComplexBin = (real: Float, imag: Float)
```

### `WindowFunction`

```swift
enum WindowFunction {
    case hann(periodic: Bool = true)
    case hamming(periodic: Bool = true)
}
```

- **periodic `true`** — 分母使用 `N`（适用于 STFT 分析/重建）
- **periodic `false`** — 分母使用 `N-1`（对称窗，适用于滤波器设计）

## 重建质量

为实现完美（或近似完美）重建，建议使用 75% 重叠：

```swift
let config = STFTConfiguration(
    fftSize: 2048,
    hopSize: 512,                    // 75% 重叠
    window: .hann(periodic: true),
    centerPadding: true
)
```

`inverse` 方法内部自动执行窗函数平方和归一化，补偿 overlap-add 的加窗效应，使重建信号与原始信号高度吻合。

## 许可证

MIT
