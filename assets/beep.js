/****************************************
 * beep.js
 * 生成 100ms, 2000Hz 的正弦波音频，
 * 并导出为 beep.wav 文件。
 ****************************************/

// 1. 基础参数设置
const sampleRate = 44100;
const duration = 0.1;      // 100ms (原先 0.05)
const frequency = 2000;    // 2000Hz
const fadeTime = 0.005;    // 5ms 的淡入淡出 (原先 0.01)

// 2. 创建音频数据存储
const samples = new Float32Array(Math.floor(sampleRate * duration));

// 3. 生成正弦波，添加淡入淡出效果
for (let i = 0; i < samples.length; i++) {
    // 基本正弦波
    const wave = Math.sin(2 * Math.PI * frequency * i / sampleRate);
    
    // 计算淡入淡出包络
    const fadeSamples = Math.floor(sampleRate * fadeTime);
    let envelope = 1.0;
    
    // 淡入
    if (i < fadeSamples) {
        envelope = i / fadeSamples;
    }
    // 淡出
    else if (i > samples.length - fadeSamples) {
        envelope = (samples.length - i) / fadeSamples;
    }
    
    // 应用包络
    samples[i] = wave * envelope;
}

// 4. 定义 WAV 文件各部分数据
const wav = {
    riff: new Uint8Array([82,73,70,70]), // "RIFF"
    size: new Uint32Array([36 + samples.length * 2]), // 文件大小(字节)
    wave: new Uint8Array([87,65,86,69]), // "WAVE"
    fmt: new Uint8Array([102,109,116,32]), // "fmt "
    fmtSize: new Uint32Array([16]), // fmt chunk size
    audioFormat: new Uint16Array([1]), // PCM
    numChannels: new Uint16Array([1]), // 单声道
    sampleRate: new Uint32Array([sampleRate]),
    byteRate: new Uint32Array([sampleRate * 2]), // (sampleRate * 通道数 * 每样本字节数)
    blockAlign: new Uint16Array([2]), // (通道数 * 每样本字节数)
    bitsPerSample: new Uint16Array([16]),
    data: new Uint8Array([100,97,116,97]), // "data"
    dataSize: new Uint32Array([samples.length * 2]), // 数据大小
    samples: new Int16Array(samples.length)
};

// 5. 将浮点样本转换成 16 位整数
for (let i = 0; i < samples.length; i++) {
    // 振幅范围：-1.0 ~ 1.0，16位整型范围：-32768 ~ 32767
    wav.samples[i] = samples[i] * 32767;
}

// 6. 构建完整的 WAV 文件
const wavFile = new Uint8Array(44 + wav.samples.length * 2);
let pos = 0;

// 写入 RIFF
wavFile.set(wav.riff, pos); 
pos += 4;

// 写入 size
wavFile.set(new Uint8Array(wav.size.buffer), pos); 
pos += 4;

// 写入 "WAVE"
wavFile.set(wav.wave, pos); 
pos += 4;

// 写入 "fmt "
wavFile.set(wav.fmt, pos); 
pos += 4;

// 写入 fmtSize
wavFile.set(new Uint8Array(wav.fmtSize.buffer), pos); 
pos += 4;

// 写入 audioFormat
wavFile.set(new Uint8Array(wav.audioFormat.buffer), pos); 
pos += 2;

// 写入 numChannels
wavFile.set(new Uint8Array(wav.numChannels.buffer), pos); 
pos += 2;

// 写入 sampleRate
wavFile.set(new Uint8Array(wav.sampleRate.buffer), pos); 
pos += 4;

// 写入 byteRate
wavFile.set(new Uint8Array(wav.byteRate.buffer), pos); 
pos += 4;

// 写入 blockAlign
wavFile.set(new Uint8Array(wav.blockAlign.buffer), pos); 
pos += 2;

// 写入 bitsPerSample
wavFile.set(new Uint8Array(wav.bitsPerSample.buffer), pos); 
pos += 2;

// 写入 "data"
wavFile.set(wav.data, pos); 
pos += 4;

// 写入 dataSize
wavFile.set(new Uint8Array(wav.dataSize.buffer), pos); 
pos += 4;

// 写入实际声音数据
wavFile.set(new Uint8Array(wav.samples.buffer), pos);

// 7. 将 WAV 文件写入磁盘 (当前目录下)
require('fs').writeFileSync('beep.wav', wavFile);

console.log('beep.wav generated successfully!');