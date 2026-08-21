# K-차원 타일링 설계 스펙 (초안)

> Gemmini류 아키텍처처럼, 고정된 물리 배열(현재 4×4)로 물리 배열보다 큰 K(축소) 차원의 행렬곱을 처리하기 위한 설계.
> 2026.08.18 작성. 목표: 기존에 실물 검증된 4×4 코어(Controller/SRAM/MAC_Unit/Systolic_Array/FIFO_All)는 **건드리지 않고**, 그 위에 얹는 방식으로 설계.

---

## 0단계. 착수 전 파라미터화 (반나절 스코프)

K-타일링을 시작하기 전에, 딱 이 작업에 필요한 값들만 먼저 `parameter`/`localparam`으로 뽑아두는 게 좋음. "전체 프로젝트 리팩토링"까지 갈 필요는 없고(오늘 실물 검증한 코드를 불필요하게 흔들 위험), K-타일링이 실제로 건드릴 값들로 스코프를 좁힐 것.

**뽑아야 할 파라미터:**

- `DATA_WIDTH` (=8, activation/weight 비트폭)
- `ACC_WIDTH` (=32, psum 비트폭)
- `ARRAY_SIZE` (=4, 배열 크기 — 지금 이 숫자가 곳곳에 매직 넘버로 하드코딩돼 있음)
- `ADDR_WIDTH` (=10, SRAM 주소 폭)

**대표적인 매직 넘버 사례** (`Controller.sv`):
```systemverilog
IDLE: begin
    wgt_offset <= 2'b11;   // = 3, 실제로는 ARRAY_SIZE-1
```
이런 곳을 하나라도 놓치면 컴파일은 되는데 조용히 잘못된 개수를 로드하는, 오늘 겪었던 것과 같은 종류의 버그가 재발할 수 있음.

**적용 대상**: `Controller.sv`, `SYSTOLIC_ARRAY.sv`, `MAC_Unit.sv`, `SKEW_Unit.sv`, `SRAM.sv`만. `FIFO`/`FIFO_All`(depth=8), UART 모듈들(`CLKS_PER_BIT`은 이미 파라미터화됨)은 K-타일링과 무관하니 이번엔 손대지 않음.

**필수 안전망 — 끝나고 반드시 회귀 테스트:**
1. `make test` (Icarus) 통과 확인
2. `make test_sva` (Verilator + SVA) 통과 확인
3. Tang Nano 9K 실물에서 오늘 만든 세 테스트(`run_identity_test`, `run_streaming_test`, `run_matmul_test`)를 다시 돌려서 리팩토링 전후 결과가 동일한지 확인

이 세 가지가 다 통과해야 "정리는 했는데 뭐가 깨졌는지 모르는" 상황을 피할 수 있음.

---

## 1. 문제 정의

지금 회로는 `K=4`(weight의 row 수 = activation vector 길이)가 물리 배열 높이와 정확히 같다고 가정하고 있음. `data_out[n] = Σᵢ A[i]·W[i][n]`을 **한 번의 weight 로드 + 한 번의 streaming pass**로 끝냄.

`K > 4`인 경우(예: K=12), 논리적 weight는 `K×N` 행렬인데 물리 배열은 `4×N`만 담을 수 있음. 이걸 처리하려면:

1. K를 4개씩 묶은 타일(K-tile)로 쪼갬 (K=12 → 3개 타일)
2. 타일마다: 그 K-tile에 해당하는 weight 4행만 로드 → 해당 activation 값들(K차원 중 그 4개 구간)로 streaming → **부분합(partial sum)** 생성
3. 부분합을 이전 타일들의 결과와 **누적(accumulate)**
4. 마지막 타일까지 끝나야 진짜 최종 결과가 확정됨

핵심은 지금 원칙 문서에도 이미 적혀있던 그 문장이야: *"Accumulator는 원래 read-modify-write 가능해야 하지만, 지금은 K차원을 안 쪼개서 단순 capture로 충분"* — 이번에 그 가정이 깨지는 거고, 이게 새로 만들어야 할 핵심 서브시스템.

---

## 2. 아키텍처 방향: 외부 Accumulator SRAM (권장)

두 가지 선택지가 있음:

- **(A) 배열 밖에서 누적**: `FIFO_All`이 뱉는 K-tile 부분합을, 별도의 Accumulator SRAM에 read-modify-write로 더해 넣음. `Systolic_Array`/`MAC_Unit`은 지금 그대로 재사용 — **전혀 안 건드림**.
- **(B) 배열 안에서 누적**: `psum_array[0][k]` 경계값을 `0` 대신 "이전 타일의 누적값"으로 주입해서, 배열 자체의 덧셈으로 누적. 배열 입력 경로를 새로 만들어야 하고, 결국 그 "이전 타일 누적값"도 어딘가(SRAM)에 저장해뒀다 다시 읽어와야 하니 저장소 필요성은 동일함.

**(A)를 추천**: 실물에서 이미 검증된 `Systolic_Array`/`MAC_Unit`을 한 줄도 안 바꾸고, 완전히 새로운 모듈 하나(Accumulator)만 추가하는 구조라 리스크가 제일 낮음. 디버깅할 때도 "배열은 원래 검증됐으니 문제면 무조건 새 모듈"이라고 바로 좁혀짐.

---

## 3. 새로 필요한 것들

### 3.1 Accumulator SRAM (신규 모듈)

- 크기: `M × N × 32비트` (M = 한 배치에서 동시에 진행 가능한 activation vector 개수, N=4 고정)
- 인터페이스: 기존 `SRAM.sv`와 비슷하게 `addr_rd`/`addr_wt` 분리, 다만 **read-modify-write**가 필요하므로 컨트롤 로직에서 "이전 값 읽기 → 더하기 → 다시 쓰기"를 최소 2사이클에 걸쳐 수행하는 시퀀서가 하나 더 필요함 (또는 SRAM 자체를 read-then-write 파이프라인으로 설계)
- 첫 K-tile(k_tile_idx==0)일 땐 이전 값을 읽지 않고 그냥 `partial_sum`을 그대로 씀(누적 아님, 초기화)
- 마지막 K-tile(k_tile_idx==num_k_tiles-1)일 때만 최종값을 host가 읽을 수 있는 상태로 노출(valid 플래그)

### 3.2 Controller 바깥 루프 (신규 상태 또는 신규 모듈)

지금 `Controller`(`IDLE→LOAD_wgt→STREAM`)를 감싸는 **한 겹 바깥 루프**가 필요함:

```
IDLE
 → K_TILE_LOOP (k_tile_idx = 0 .. num_k_tiles-1):
     → LOAD_wgt (이번 k_tile의 weight 4행, base_addr_wgt + k_tile_idx*4 + offset)
     → STREAM   (activation M개, 이번 k_tile 구간만 — activation SRAM 주소도 k_tile_idx 반영)
     → (Accumulator가 이번 pass 결과를 이전 값에 누적)
   k_tile_idx == num_k_tiles-1 이면 결과 valid 세팅 후 IDLE 복귀
```

기존 `Controller.sv`를 직접 확장할지, 아니면 `Controller`는 그대로 두고 그 위에 새 `TileController` 모듈을 하나 얹어서 `run`/`load_wgt`를 K-tile 횟수만큼 자동으로 재발동시킬지 — **후자를 추천**. 기존 `Controller`도 실물 검증된 상태라 안 건드리는 게 안전함.

### 3.3 SRAM 주소 체계 확장

- Weight SRAM: 지금 `base_addr_wgt + offset(0~3)` → `base_addr_wgt + k_tile_idx*4 + offset(0~3)`으로 확장 (그냥 base를 타일마다 다르게 잡아주면 됨, 주소 폭만 넉넉한지 확인)
- Activation SRAM: 지금은 벡터 하나가 32비트 워드 하나(4개 int8)로 끝났는데, K>4면 **벡터 하나가 여러 워드**로 늘어남 (K=12면 벡터당 3워드). `activation vector m, k_tile kt`의 주소 = `base_addr_act + m*num_k_tiles + kt` 같은 식으로 재설계 필요 — 이 부분이 사실 제일 헷갈리기 쉬운 지점이니 먼저 종이에 주소 매핑표부터 그려보고 시작하는 걸 추천

### 3.4 호스트 레지스터 맵 추가

지금 `UART_Bridge`의 레지스터맵에 최소 1개 추가 필요:

- `ADDR_NUM_K_TILE` (신규): K를 몇 개의 4단위 타일로 쪼갤지
- 기존 `num_act`는 그대로 "한 K-tile pass당 몇 개의 activation을 스트리밍할지"로 재해석하면 됨

---

## 4. 먼저 결정해야 할 것들 (구현 착수 전에)

1. **M(배치 크기) 상한을 얼마로 할지** — Accumulator SRAM 크기를 결정짓는 값. 처음엔 M=4~8 정도로 작게 잡고 시작하는 걸 추천 (검증 쉬움)
2. **K가 4의 배수가 아닌 경우 처리 여부** — 처음 버전은 "K는 항상 4의 배수"로 가정하고 패딩/나머지 처리는 스코프 밖으로 미루는 걸 추천 (시간 절약)
3. **Accumulator read-modify-write를 몇 클럭에 끝낼지** — SRAM 1클럭 read latency 감안하면 최소 read 1클럭 + add 1클럭 + write 1클럭 정도의 파이프라인이 필요함, 이 타이밍 설계를 제일 먼저 종이로 그려볼 것 (SRAM latency 관련해서 이미 두 번이나 버그 냈던 전례가 있으니 이번엔 처음부터 타이밍 표 그리고 시작하길 권장)

---

## 5. 검증 계획

1. Accumulator SRAM 단독 유닛 테스트 (Icarus) — read-modify-write가 정확한지, 첫 타일 초기화 vs 이후 누적 구분이 맞는지
2. K=8(2타일), M=1 activation 하나로 최소 재현 시나리오부터 (손으로 계산 가능한 작은 행렬로 golden model 비교)
3. 기존 `tb_System.sv` 패턴 재사용해서 K=8/12, M=여러 개 조합으로 확장
4. SVA 추가: "마지막 타일 전엔 절대 result_valid가 뜨면 안 된다", "Accumulator 인덱스가 M 범위를 벗어나면 안 된다" 등 — 지금까지 만든 SVA 세트에 자연스럽게 이어붙이기
5. 시뮬레이션 통과 후에만 Tang Nano 9K로 이식 (오늘처럼 하드웨어에서 처음부터 디버깅하지 않도록)

---

## 6. 남겨두는 것 (이번 스코프 밖)

- N(출력 차원)이 4보다 큰 경우 — 이번엔 다루지 않음, K-타일링만 먼저
- M이 accumulator 용량을 초과하는 경우의 흐름제어 — 이번엔 M 상한 내에서만 동작하는 걸로 스코프 제한
- 배열 자체 크기 확장(4×4→8×8) — K-타일링이 먼저 동작 확인된 뒤에 별도로 고려
