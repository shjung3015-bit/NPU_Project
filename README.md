# Systolic Array NPU (Weight-Stationary)

FPGA 위에 시스톨릭 어레이 기반 소형 NPU(행렬곱 가속기)를 처음부터 설계해보는 개인 프로젝트입니다. 컴퓨터구조 수업에서 멀티사이클 프로세서 RTL 과제를 하다가 흥미가 생겼고, 학교 종합설계 팀이 FPGA에 Gemmini + RocketChip을 올려 AI 가속기를 만든 영상을 보고 직접 만들어보고 싶어서 시작했습니다. SystemVerilog로 RTL을 설계하고, Icarus Verilog / Verilator + SVA로 시뮬레이션 검증한 뒤, Tang Nano 9K FPGA에 실제로 올려서 동작을 확인하는 것까지가 목표입니다.

## 개요

- **연산 코어**: 4×4 시스톨릭 어레이(weight-stationary) 기반 행렬곱 가속기
- **K-타일링**: 물리 배열(4×4)보다 큰 K(축소) 차원을 여러 타일로 쪼개서, 외부 Accumulator SRAM에서 read-modify-write로 부분합을 누적
- **호스트 인터페이스**: UART로 레지스터 맵 기반 프로토콜(WRITE/READ + 주소 + 데이터)을 통해 host(PC)와 통신
- **검증**: Icarus Verilog 시뮬레이션 + Verilator 기반 SystemVerilog Assertion(SVA)으로 이중 검증 후 실물 FPGA(Tang Nano 9K)에서 브링업

## 아키텍처

```
Top_Module
├── UART_Bridge              호스트 ↔ FPGA 간 레지스터 맵 프로토콜 처리
│   ├── UART_RX
│   └── UART_TX
├── Systolic_Core             4×4 시스톨릭 어레이 코어 한 패스(pass)
│   ├── Controller             LOAD_WGT → STREAM 시퀀싱
│   ├── SRAM (wgt / act)       가중치·활성값 버퍼
│   ├── Systolic_Array         MAC_Unit × 4×4 + SKEW_Unit
│   └── FIFO_All               코어 출력 결과 버퍼링/드레인
└── Accumulator                K-tile 부분합 read-modify-write 누적 + 최종 결과 팝아웃
    ├── SRAM × 4 (lane별)
    └── Adder × 4
```

> **진행 중**: `Systolic_Core`와 `Accumulator`를 감싸서 K-tile 루프(가중치 재로드 → 스트리밍 → 누적)를 하드웨어에서 자동으로 반복하는 `LoopMatmul` 컨트롤러를 설계 중입니다. 완성되면 위 계층에서 `LoopMatmul`이 `Systolic_Core`/`Accumulator`를 감싸는 형태로 바뀌고, host는 K-tile 개수만 지정하면 나머지는 하드웨어가 알아서 처리하게 됩니다. 지금은 host(UART)가 매 K-tile마다 `AddEna`/`TileStart`를 직접 제어합니다.

## 현재 상태

- [x] 4×4 시스톨릭 어레이 코어 (weight-stationary), FPGA 실물 검증 완료
- [x] UART 기반 host-device 레지스터 맵 프로토콜
- [x] Accumulator: K-tile read-modify-write 누적, `TileStart`/`Pop` 엣지 검출, 순차 팝아웃 — 시뮬레이션 검증 완료
- [x] SVA 기반 정형 검증 (`FIFO`, `FIFO_All`, `SRAM`, `Controller`, `MAC_Unit`, `Systolic_Array`)
- [ ] `LoopMatmul` — K-tile 루프 하드웨어 자동화 (설계 중)
- [ ] N(출력 열) 방향 타일링
- [ ] 실제 신경망 레이어(예: 양자화된 소형 MLP) 가속 데모

## 레포 구조

| 경로 | 내용 |
|---|---|
| `src/` | RTL 소스 (SystemVerilog) |
| `tb/` | Icarus Verilog 테스트벤치 |
| `sva/` | SystemVerilog Assertion + bind 파일 |
| `docs/` | 설계 스펙, 스터디 노트 (`K_Tiling_Design_Spec.md` 등) |
| `host/` | 호스트 측 파이썬 스크립트 (UART 통신, 알고리즘 검증용) |
| `fpga_bringup/` | Tang Nano 9K 제약 파일, 비트스트림, 브링업용 스크립트 |
| `CONVENTIONS.md` | RTL 네이밍/코딩 컨벤션 규칙 |

## 빌드 & 테스트

Icarus Verilog와 Verilator가 필요합니다.

```bash
make test              # 전체 시스템 테스트벤치 (Icarus)
make test_accumulator  # Accumulator 단독 테스트벤치 (Icarus)
make test_sva          # Verilator + SVA 정형 검증
make wave               # 파형(GTKWave) 확인
```

## 참고 문서

- [`docs/K_Tiling_Design_Spec.md`](docs/K_Tiling_Design_Spec.md) — K-타일링 설계 스펙
- [`docs/SVA_Study_Guide.md`](docs/SVA_Study_Guide.md) — SVA 학습 노트
- [`docs/Coverage_Study_Guide.md`](docs/Coverage_Study_Guide.md) — 커버리지 학습 노트
- [`CONVENTIONS.md`](CONVENTIONS.md) — RTL 네이밍/코딩 컨벤션
