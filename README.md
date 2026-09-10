# Systolic Array NPU (Weight-Stationary)

FPGA 위에 시스톨릭 어레이 기반 소형 NPU(행렬곱 가속기)를 처음부터 설계해보는 개인 프로젝트입니다. 컴퓨터구조 수업에서 멀티사이클 프로세서 RTL 과제를 하다가 흥미가 생겼고, 학교 종합설계 팀이 FPGA에 Gemmini + RocketChip을 올려 AI 가속기를 만든 영상을 보고 직접 만들어보고 싶어서 시작했습니다. SystemVerilog로 RTL을 설계하고, Icarus Verilog / Verilator + SVA로 시뮬레이션 검증한 뒤, Tang Nano 9K FPGA에 실제로 올려서 동작을 확인하는 것까지가 목표입니다.

## 개요

- **연산 코어**: 4×4 시스톨릭 어레이(weight-stationary) 기반 행렬곱 가속기
- **K/N-타일링**: 물리 배열(4×4)보다 큰 K(축소)·N(출력 열) 차원을 각각 타일로 쪼개서 하드웨어가 중첩 루프로 자동 처리 — K-tile끼리는 Accumulator에서 read-modify-write로 부분합 누적, N-tile끼리는 서로 다른 주소 구간에 결과 저장
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
├── Accumulator                K/N-tile 부분합 read-modify-write 누적 + N-tile별 주소 확장 + 최종 결과 팝아웃
│   ├── SRAM × 4 (lane별)
│   └── Adder × 4
└── N_LoopMatmul               N-tile 루프 자동화: N-tile마다 K_LoopMatmul을 재트리거
    └── K_LoopMatmul           K-tile 루프 자동화: 가중치 재로드 → 스트리밍 → 누적을 하드웨어가 반복
```

`Systolic_Core`/`Accumulator`를 감싸는 대신, `N_LoopMatmul`은 `Top_Module` 아래 형제 모듈로 두고 `run`/`Load_wgt`/`BaseAddr_wgt`/`BaseAddr_act`/`TileStart`/`AddEna` 6개 제어 신호만 `Top_Module` 레벨에서 먹스(`LoopActive || LoopStart` 선택)로 중재합니다. 평소엔 host(UART)가 이 신호들을 직접 제어하고(수동 모드), host가 `LoopStart`를 올리면 `N_LoopMatmul`이 `Num_N_Tile`만큼 N-tile을 자동으로 순회하며, N-tile마다 내부의 `K_LoopMatmul`을 재트리거해 그 안에서 다시 `Num_K_Tile`만큼 K-tile 루프를 완주시킵니다(중첩 루프 자동화). N-tile끼리는 서로 다른 출력이라 섞이면 안 되므로, `Accumulator`는 `N_LoopMatmul`이 계산해주는 `N_TileBase_REG`를 기준 주소로 받아 N-tile마다 다른 주소 구간에 결과를 쌓습니다. `K_LoopMatmul`의 활성값 주소 스트라이드는 `Num_act`(M) 기반이라, M이 4보다 작거나 커도(4의 배수가 아니어도) 그대로 동작합니다.

## 현재 상태

- [x] 4×4 시스톨릭 어레이 코어 (weight-stationary), FPGA 실물 검증 완료
- [x] UART 기반 host-device 레지스터 맵 프로토콜
- [x] Accumulator: K/N-tile read-modify-write 누적 + N-tile별 주소 확장(`N_TileBase_REG`), `TileStart`/`Pop` 엣지 검출, 순차 팝아웃 — 시뮬레이션 검증 완료
- [x] SVA 기반 정형 검증 (`FIFO`, `FIFO_All`, `SRAM`, `Controller`, `MAC_Unit`, `Systolic_Array`)
- [x] `K_LoopMatmul` — K-tile 루프 하드웨어 자동화, 활성값 주소 스트라이드를 `Num_act`(M) 기반으로 일반화(M이 4보다 작거나 커도 동작) — RTL + 시뮬레이션 검증 완료
- [x] `N_LoopMatmul` — N-tile 루프 하드웨어 자동화(`K_LoopMatmul`을 감싸는 중첩 구조) + Accumulator N-tile 주소 확장 — RTL + 시뮬레이션 검증 완료, golden model 대비 전부 일치
- [ ] K/N이 ARRAY_SIZE(4)의 배수가 아닌 경우(나머지 처리/제로 패딩)
- [ ] `K_LoopMatmul`/`N_LoopMatmul` FPGA 실물 브링업 (현재 시뮬레이션 검증만 완료)
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
make test_loopmatmul   # K_LoopMatmul 하드웨어 K-타일 루프 테스트벤치, K=4/8/12 (Icarus)
make test_n_loopmatmul # N_LoopMatmul 하드웨어 N/K-타일 중첩 루프 테스트벤치, M<4/=4/>4 포함 (Icarus)
make test_sva          # Verilator + SVA 정형 검증
make wave               # 파형(GTKWave) 확인
```

## 참고 문서

- [`docs/K_Tiling_Design_Spec.md`](docs/K_Tiling_Design_Spec.md) — K-타일링 설계 스펙
- [`docs/SVA_Study_Guide.md`](docs/SVA_Study_Guide.md) — SVA 학습 노트
- [`docs/Coverage_Study_Guide.md`](docs/Coverage_Study_Guide.md) — 커버리지 학습 노트
- [`CONVENTIONS.md`](CONVENTIONS.md) — RTL 네이밍/코딩 컨벤션
