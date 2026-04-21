# STFTKit

**纯 Swift 实现的零依赖 STFT/iSTFT 库，支持 iOS 和 macOS。**

> 每次需要频谱分析都要手动封装 vDSP？STFTKit 为你提供了一个简洁的 Swift API，用于短时傅里叶变换——不多不少，刚刚好。

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2016+|macOS%2013+-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 一句话上手

```swift
import STFTKit

let stft = STFT()
let spectrogram = stft.forward(audioSignal)
let reconstructed = stft.inverse(spectrogram)  // 几乎完美重建！
```

- ✅ **零外部依赖** — 仅使用 Swift + Apple Accelerate
- ✅ **完美重建** — Overlap-add + 窗函数归一化
- ✅ **实时就绪** — 单帧 FFT，支持流式处理
- ✅ **纯 Swift** — 无桥接，无 C 代码
- ✅ **功能完备** — Hann/Hamming 窗函数、幅度/相位提取

---

## 为什么选择 STFTKit？

如果你在 iOS 上做过频谱分析，可能遇到过这些问题：

| 方案 | 问题 |
|------|------|
| **AudioKit** | 功能强大，但体系庞大。想跑个 FFT 得先搞懂 node graph。 |
| **直接用 vDSP** | 每次都要写 50+ 行模板代码：split complex 数组、初始化 setup、bin 打包…… |
| **第三方封装** | 通常不完整——只有正向 FFT，没有逆变换，或无法完美重建。 |

**STFTKit 不一样。** 它是一个单一用途的库，只做一件事：把 STFT 做对做好。

### 与同类库对比

| 功能 | **STFTKit** | AudioKit | AuraSignal | TempiFFT |
|------|:-----------:|:--------:|:----------:|:---------:|
| **定位** | 专注 STFT | 全功能音频平台 | DSP 工具箱 | 实时频谱 |
| **STFT + iSTFT** | ✅ 完美 | ⚠️ 部分 | ✅ | ❌ 仅有正向 |
| **外部依赖** | 零依赖 | 重依赖 | Swift Numerics | 零依赖 |
| **逆变换** | ✅ | ⚠️ | ✅ | ❌ |
| **中心零填充** | ✅ | ❌ | ❌ | ❌ |
| **文档** | 中英双语 | 英文 | 英文 | 英文 |
| **API 复杂度** | 低 | 高 | 中 | 中 |

---

## 安装

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/hohband/STFTKit.git", from: "1.0.0")
]
```

```swift
// 目标依赖
.target(name: "YourApp", dependencies: ["STFTKit"])
```

### Xcode

文件 → 添加包依赖 → `https://github.com/hohband/STFTKit.git`

---

## 快速上手

### 基础用法

```swift
import STFTKit

// 使用默认配置创建（fftSize=2048, hopSize=1024, Hann 窗）
let stft = STFT()

// 正向变换：信号 → 频谱图
let spectrogram = stft.forward(audioSamples)

// 逆向变换：频谱图 → 信号（几乎完美重建）
let reconstructed = stft.inverse(spectrogram)
```

### 自定义配置

```swift
let config = STFTConfiguration(
    fftSize: 4096,                    // FFT 窗口大小（2 的幂）
    hopSize: 1024,                    // 帧间步长
    window: .hann(periodic: true),  // Hann 或 .hamming
    centerPadding: true               // 零填充信号中心对齐
)

let stft = STFT(configuration: config)
```

### 推荐配置：75% 重叠实现完美重建

```swift
let config = STFTConfiguration(
    fftSize: 2048,
    hopSize: 512,    // 75% 重叠 → 完美重建
    window: .hann(periodic: true),
    centerPadding: true
)
```

---

## API 参考

### 全信号处理

#### `forward(_:)` — 信号转频谱图

```swift
public func forward(_ signal: [Float]) -> Spectrogram
```

将完整音频信号转换为频谱图（时频表示）。

#### `inverse(_:)` — 频谱图转信号

```swift
public func inverse(_ spectrogram: Spectrogram) -> [Float]
```

使用 overlap-add + 窗函数归一化从频谱图重建时域信号。

> **注意**：使用 75% 重叠（hopSize = fftSize/4）+ Hann 窗时，重建误差低于 `1e-5`。

---

### 幅度与相位

#### `magnitudes(from:)`

```swift
public func magnitudes(from spectrogram: Spectrogram) -> [Float]
```

从频谱图中提取幅度值，用于可视化或后续处理。

#### `spectrogram(fromMagnitudes:phases:frameCount:)`

```swift
public func spectrogram(fromMagnitudes: [Float], phases: [Float], frameCount: Int) -> Spectrogram
```

从幅度和相位数组重建频谱图——适用于频谱编辑、噪声消除等场景。

---

### 单帧处理（实时 / 流式）

```swift
// 逐帧处理（例如从音频缓冲区回调）
let spectrum: ComplexSpectrum = stft.processFrame(audioFrame)

// 重建单帧
let samples: [Float] = stft.reconstructFrame(spectrum)
```

---

### 辅助方法

```swift
// 压缩格式 → 完整频谱（直流到奈奎斯特）
let fullBins: [ComplexBin] = stft.packedToFull(spectrum)

// 完整频谱 → 压缩格式（用于逆 FFT）
let packed: ComplexSpectrum = stft.fullToPacked(fullBins)
```

---

## 配置参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `fftSize` | 2048 | FFT 窗口大小（必须为 2 的幂） |
| `hopSize` | 1024 | 帧间步长（采样点数） |
| `window` | `.hann(periodic: true)` | 窗函数类型 |
| `centerPadding` | `true` | 零填充信号，使帧中心对齐边缘 |

### 计算属性

```swift
config.frequencyBins  // fftSize / 2 + 1（直流到奈奎斯特）
config.packedBins     // fftSize / 2（Accelerate 压缩格式）
```

---

## 适用场景

STFTKit 适用于：

- 🎤 **噪声消除** — 分析频率成分，应用频谱减法
- 📊 **频谱可视化** — 将音频显示为时频热力图
- 🎵 **音频效果** — 变频（通过幅度操作实现时间拉伸、音高变换）
- 🔊 **声音分析** — 音高检测、onset 检测、乐器识别
- 🎙 **语音处理** — 语音活动检测、声学特征提取
- 📱 **音乐应用** — 调音器、音频编辑器、播客工具

---

## 数据类型

### `Spectrogram`

多帧复数频域表示的容器。

```swift
public struct Spectrogram {
    public var frames: [[ComplexBin]]  // [帧][频率 bin]

    public var frameCount: Int { frames.count }
    public var frequencyBins: Int { frames.first?.count ?? 0 }

    // 二维下标访问
    public subscript(frame: Int, bin: Int) -> ComplexBin
}
```

### `ComplexSpectrum`

用于 Accelerate FFT 操作的压缩复数数组。

```swift
public struct ComplexSpectrum {
    public var real: [Float]  // 实部
    public var imag: [Float]  // 虚部
    public var binCount: Int { real.count }
}
```

### `ComplexBin`

单个频率 bin 的便捷类型别名：

```swift
public typealias ComplexBin = (real: Float, imag: Float)
```

### `WindowFunction`

```swift
public enum WindowFunction: Sendable {
    case hann(periodic: Bool = true)
    case hamming(periodic: Bool = true)
}
```

---

## 系统要求

| 要求 | 版本 |
|------|------|
| Swift | 5.9+ |
| iOS | 16.0+ |
| macOS | 13.0+ |
| 框架 | Apple Accelerate |

---

## 测试

STFTKit 包含完整的测试覆盖：

```bash
# 运行所有测试
swift test --enable-test-discovery

# 运行特定测试套件
swift test --filter STFTTests
```

测试覆盖：
- ✅ 完美重建精度（NRMSE < 1e-4）
- ✅ 多种 FFT 大小（512, 1024, 2048, 4096）
- ✅ 不同重叠率（50%, 75%, 87.5%）
- ✅ 所有窗函数（Hann, Hamming, 周期/对称）
- ✅ 幅度/相位提取与重建
- ✅ 边界情况（空信号、短信号）
- ✅ 性能基准测试

---

## 示例

查看 `Examples/` 目录：
- **macOS CLI Demo** — 命令行运行 FFT 分析
- **iOS 可视化** — 实时频谱显示（开发中）

---

## 贡献

欢迎提交 Pull Request！

1. Fork 本仓库
2. 创建功能分支（`git checkout -b feature/amazing-feature`）
3. 提交更改（`git commit -m 'Add amazing feature'`）
4. 推送分支（`git push origin feature/amazing-feature`）
5. 创建 Pull Request

---

## 许可证

MIT 许可证 — 详见 [LICENSE](LICENSE)。

---

## 致谢

基于 [Apple Accelerate 框架](https://developer.apple.com/documentation/accelerate) 构建，使用硬件优化的 FFT 运算。
