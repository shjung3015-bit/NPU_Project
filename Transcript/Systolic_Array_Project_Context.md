# 2026 여름방학 하드웨어 가속기 설계 프로젝트 - 컨텍스트 요약

이 문서는 다른 Claude 세션(데스크톱 앱 등)에 붙여넣어, 지금까지의 작업 맥락을 이어받기 위한 요약입니다.

## 프로젝트 개요

- **목표**: Weight-Stationary 시스톨릭 어레이 기반 NPU/하드웨어 가속기를 SystemVerilog로 설계·검증. **취업/대학원 포트폴리오용**으로 진행 중.
- **기간**: 2026.06.25 ~ 여름방학(8/31) 집중, 필요 시 학기 중에도 계속
- **작업 방식**: 사용자는 Cowork(개념 이해/설계 리뷰/방향 결정)와 Claude Code(실제 구현/디버깅/시뮬레이션, Icarus Verilog + GTKWave 사용)를 병행. 작업 파일은 `C:\Users\정세헌\Desktop\Systolic_array` 폴더에 있음.
- **Notion 프로젝트 페이지**: `3a5da0cc-48bf-808e-a109-e45c915d2b7f` ("[2026 여름방학 하드웨어 가속기 설계 프로젝트]") — 날짜별 개발일지(진행 내용/트러블슈팅/검증 결과/코드 원본 형식)가 06/25부터 08/02까지 기록되어 있음. Claude Code가 작성/디버깅한 코드는 정직하게 라벨링함.
- **로드맵**:
  - Phase 1: NPU 코어 완성 (SRAM + 주소생성 + 컨트롤러 FSM) — **거의 완료**
  - Phase 2: 검증 역량 보강 (SVA + Functional Coverage) — 예정, Icarus Verilog의 concurrent assertion 지원이 제한적이라 필요시 Verilator(WSL 필요) 전환 고려 중
  - Phase 3: FPGA 실물 검증 — 보드 후보 조사 중 (아래 참고)
  - Phase 4: 오픈소스 ASIC 플로우 (LibreLane + Sky130 PDK)
  - Phase 5: (스트레치) Tiny Tapeout

## 현재 RTL 아키텍처 (2026.08.02 기준)

파일 위치: `C:\Users\정세헌\Desktop\Systolic_array\`

- **MAC_Unit.sv**: 4×4 배열의 기본 PE. weight는 `load_en`으로만 캡처(역순 4행 로딩), activation/psum은 `in_valid`로 흐름. 20/20 테스트 통과, 안정적.
- **SKEW_Unit.sv**: activation을 행별로 대각선 스큐(diagonal skew)해서 시스톨릭 배열에 공급. weight는 스큐 불필요(제거됨).
- **SYSTOLIC_ARRAY.sv** (구 Top_Module): `genvar`/`generate`로 4×4 MAC_Unit 배열 구성, (5×5) 여유 배열로 경계 처리. `data_valid[3:0]` 출력 추가됨(컬럼별 출력 valid, `in_valid_array[3][k+1]`에서 가져옴).
- **SRAM.sv**: `addr_rd`/`addr_wt` 분리된 read/write 주소 버스(simple dual-port 스타일), 1클럭 registered read latency. weight/activation 각각 별도 인스턴스(SRAM_wgt, SRAM_act).
- **Controller.sv**: FSM = `IDLE → LOAD_wgt → STREAM` (기존 ACT/WAIT/DONE 구조에서 단순화됨). `LOAD_wgt`는 weight 4행을 역순으로 읽어 로딩. `STREAM`은 `num_act`개의 activation을 `inject_ena`가 허용하는 동안 연속으로 주입(continuous streaming). `addr_wgt`/`addr_act`는 `base_addr + offset` 방식.
- **FIFO.sv**: depth-8 circular buffer, 포인터에 extra bit을 둬서 empty(`wr_ptr==rd_ptr`)/full(`주소 같은데 extra bit만 다름`) 판별. read/write를 독립된 `if`문으로 분리(동시 발생 시 데이터 유실 버그 수정됨).
- **FIFO_All.sv**: 컬럼별 FIFO 4개 + join 로직(`all_ready` = 4개 전부 non-empty일 때만 동시 pop) + **credit 기반 흐름제어**(`counter`, 0~8, "배열 안에 흐르는 것 + FIFO에 쌓인 것"을 합쳐서 관리 → `inject_ena = counter < 8`). `pop_fire`(조합, FIFO 구동용)와 `output_valid`(1클럭 지연된 레지스터, 소비자용)를 분리해서 타이밍 버그 해결.
- **Top_Module.sv**: Controller + SRAM_wgt + SRAM_act + Systolic_Array + FIFO_All을 배선. SRAM의 write 포트(`ena`/`wea`/`addr_wt`/`din`)는 Controller가 아니라 Top_Module의 외부 입력으로 직접 노출(호스트/테스트벤치가 직접 구동, Controller는 read-side만 담당).
- **Capture_REG.sv**: 초기 버전(레지스터 4개+비트마스크로 결과 캡처), streaming 지원 안 돼서 FIFO_All로 대체됨. 현재 미사용, `endmodule` 누락된 미완성 상태로 방치(삭제 여부 미정).
- **tb_System.sv**: 전체 시스템 통합 테스트벤치. 실제 SRAM write 포트를 통해 데이터 적재(readback 검증 포함), 4개 컬럼이 순서대로 valid되는지, result/result_valid 타이밍까지 검증. 5회 랜덤 trial 전부 PASS.

## 핵심 설계 원칙/개념 (대화 중 정리된 것들)

- **Moore FSM**: 출력은 오직 `state`(및 그 부속 카운터)만의 함수. 입력이나 `next_state`가 출력 계산에 직접 섞이면 Mealy 스타일이 됨.
- **조합 논리(assign/always_comb)는 메모리가 없어서 리셋이 필요 없음** — `rst_n`은 레지스터(`always_ff`)에만 필요.
- **SRAM 1클럭 registered read latency**: `enb`/`addr`를 조합(`assign`)으로 만들어 `addr`와 같은 클럭에 켜지게 해야, 이미 존재하던 `load_en`/`start`의 1클럭 지연이 자연스럽게 SRAM latency와 맞아떨어짐.
- **메모리 계층**: DRAM(외부, 아직 없음) → Scratchpad SRAM(weight/act, 만듦) → Systolic Array 연산 → Accumulator/Output Queue(만듦, 현재는 단순 capture가 아니라 FIFO). "Accumulator"는 원래 read-modify-write 가능해야 하지만, 지금은 K차원을 안 쪼개서(4×4 한 번에 계산) 단순 capture로 충분.
- **Credit 기반 흐름제어**: `occupied`만 보고 마진(almost_full)을 얹는 대신, "주입 시점부터 소비 시점까지"를 하나의 카운터(`committed_count`)로 묶어서 관리하면 반응 지연 없이 정확한 시점에 흐름제어 가능. 지금 설계에서 FIFO 깊이는 8이면 충분(16 불필요).
- **컬럼별 FIFO + join(`all_ready`)**: 시스톨릭 어레이의 컬럼별 출력 latency가 계단식으로 다른 문제를, 별도 de-skew 지연 레지스터 없이 "4개 FIFO가 전부 non-empty일 때만 동시 pop"으로 자연스럽게 해결. 실제 상용 설계(다중 레인 + join)와 유사한 패턴.
- **Count 기반 vs Level 기반 streaming 제어**: 데이터가 미리 정해진 크기로 저장되어 있으면(현재 프로젝트처럼 SRAM에 미리 로딩) count 기반(`num_act`)이 적합. 실시간/비동기 외부 소스(카메라, 네트워크)면 level 기반(AXI-Stream 스타일)이 적합.
- **Verilog 벡터의 wrap-around**: 고정폭 벡터 연산은 넘치는 비트를 자동으로 잘라서 순환(C의 unsigned overflow와 동일 메커니즘, 배열 범위 초과와는 다름) — Circular FIFO 포인터 증가에 자연스럽게 활용됨.

## FPGA 구매 관련 결론 (Phase 3용, 아직 미구매)

- 예산을 40만원까지 확장 검토, 최종적으로 **Kria KV260 Vision AI Starter Kit**(Zynq UltraScale+ ZU5EV, 로직셀 256K, DSP 1248개, Cortex-A53 쿼드코어)을 추천함 — AI 가속기 전용 설계, DPU 레퍼런스와 비교 가능, 최신 세대.
- 가격: $249~284 (DigiKey 기준), 파워서플라이($25, 12V/3A 별매, 국내서 5.5×2.5mm 규격으로 저렴하게 구매 가능), microSD는 기존 것 사용 가능(16GB+ Class10 권장).
- DigiKey 직구 시 $200 초과로 관세($10% 부가세 + 통관대행료) 발생 예상, 국내 리셀러(디바이스마트, 아이홈)도 대안으로 확인됨.
- SK-KV260-G-ED는 "Encryption Disabled" 버전(수출규제 대응), 이 프로젝트엔 기능 차이 없음.

## 현재 남은 작업 (다음에 이어서 할 것)

1. `enb_act` 게이팅은 이미 `inject_ena && act_offset<num_act`로 개선 완료
2. `result_valid`를 `Top_Module`의 외부 출력 포트로 노출 (현재 내부적으로만 존재)
3. `Capture_REG.sv` 삭제 여부 결정 (현재 미완성 상태로 방치)
4. Phase 2(SVA + Functional Coverage) 착수 예정
5. Phase 3 FPGA 실물 검증 — Kria KV260 실제 구매 여부 결정 필요

---
*이 요약은 2026-08-03 기준 Cowork 세션에서 생성되었습니다. 원본 대화가 로컬 세션이라 다른 기기/세션에 자동 동기화되지 않아, 이 파일로 맥락을 이어받기 위해 작성했습니다.*
