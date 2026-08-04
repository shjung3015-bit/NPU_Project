# Functional Coverage 스터디 가이드

> NPU_Project (Weight-Stationary Systolic Array) Phase 2 검증 역량 보강용, 2부.
> SVA_Study_Guide.md의 6절("SVA와 짝을 이루는 도구")에서 예고했던 내용을 본격적으로 다룸.
> 개념 → 문법 → 실제 프로젝트 코드(Controller / FIFO_All / SKEW_Unit) 적용 → Verilator 실행 순서로 구성.
> 2026.08.04 작성.

---

## 1. SVA와 무엇이 다른가

SVA_Study_Guide.md 1절에서 정리했던 문장을 그대로 다시 가져오면: assertion은 **"규칙이 매 순간 지켜지는가"**를 본다. Functional coverage는 **"의미 있는 시나리오를 실제로 다 실행해봤는가"**를 본다. 완전히 다른 질문이다.

둘의 관계를 이렇게 정리할 수 있다:

- SVA가 하나도 안 걸렸다 → "지켜야 할 규칙이 깨진 적은 없다"는 뜻. 하지만 **애초에 그 규칙이 시험대에 오를 만한 상황을 한 번도 안 만들었을 수도 있다.**
- Coverage가 100%다 → "의도했던 시나리오는 최소 한 번씩 다 실행해봤다"는 뜻. 하지만 **그 실행 결과가 맞는지는 별도로 확인해야 한다.**

즉 coverage 혼자서는 아무것도 검증하지 못한다. "테스트가 충분히 다양했는가"만 알려줄 뿐이다. 그래서 항상 SVA(혹은 golden model 비교)와 **짝을 이뤄서** 써야 의미가 있다: coverage로 "안 해본 시나리오"를 찾아내고, 그 시나리오를 실행하는 새 테스트를 추가하고, 그 실행 중에 SVA가 규칙 위반을 잡아준다.

프로젝트에 바로 적용해보면: 지금 `act_offset`이 `num_act`를 절대 못 넘는다는 SVA(`p_stream_exits_at_num_act`)는 이미 있다. 근데 이 assertion이 "제대로 시험대에 올랐는지"는 어떻게 아는가? `num_act=1`짜리 테스트만 계속 돌렸다면, 이 assertion은 한 번도 의미 있게 도전받은 적이 없다. Coverage는 바로 이런 맹점을 찾아준다 — "`num_act`의 어떤 값들을 실제로 테스트해봤는가"를 기록해서 보여주기 때문이다.

---

## 2. 핵심 개념: Code Coverage vs Functional Coverage

이 둘을 섞어서 생각하면 안 된다.

**Code Coverage** (line/toggle/branch/expression coverage): 시뮬레이터가 **RTL 코드 구조**를 보고 자동으로 계산한다. "이 줄이 실행됐는가", "이 신호의 이 비트가 0→1로 토글됐는가" 등. 사람이 뭘 정의할 필요 없이 툴이 알아서 계산해준다.

**Functional Coverage** (`covergroup`/`coverpoint`): **설계자가 직접** "이런 값/시퀀스가 의미 있다"고 선언한다. 예를 들어 `num_act`가 1부터 1023까지 어떤 값이든 코드 커버리지 관점에서는 "이 신호가 존재한다"는 사실 하나로 끝이지만, 기능적으로는 "2비트 wrap 경계였던 3~4 근처 값을 실제로 테스트해봤는가"가 훨씬 중요한 질문이다. 이건 사람이 도메인 지식으로 정의해야 툴이 추적해준다.

이번 가이드는 후자(functional coverage)에 집중한다. 코드 커버리지는 Verilator가 `--coverage-line`/`--coverage-toggle`로 이미 거의 공짜로 주기 때문에 (8절 참고), 따로 손으로 설계할 게 많지 않다.

---

## 3. `covergroup`/`coverpoint` 문법 뼈대

### 3.1 기본 구조

```systemverilog
covergroup cg_name @(posedge clk);
    coverpoint signal_name {
        // bins 정의
    }
endgroup

cg_name cg_inst = new();  // 인스턴스화해야 실제로 동작함
```

- `covergroup`은 클래스와 비슷하게 **인스턴스화**가 필요하다. 선언만 하면 아무 일도 안 일어난다.
- `@(posedge clk)`처럼 clocking event를 covergroup 선언에 직접 붙이면, 매 클럭마다 자동으로 샘플링된다. (SVA의 `@(posedge clk)`와 같은 감각.)
- clocking event를 안 붙이고 싶다면 `cg_inst.sample()`을 원하는 시점에 직접 호출하는 방식도 가능하다 — 예를 들어 "STREAM 상태일 때만 샘플링하고 싶다"처럼 조건부 샘플링이 필요할 때 유용하다.

### 3.2 bins 종류

```systemverilog
coverpoint num_act {
    bins small        = {[1:2]};        // 범위 bin
    bins wrap_boundary = {3, 4};         // 특정 값 여러 개를 한 bin으로 묶기
    bins large        = {[5:$]};         // $는 "최댓값까지" (SVA의 ##[1:$]와 같은 의미)
    illegal_bins never = {0};            // 이 값이 나오면 즉시 에러 (num_act=0은 설계상 있으면 안 됨)
    ignore_bins skip   = default;        // 위에서 안 다룬 나머지 값은 커버리지 계산에서 제외
}
```

- 아무것도 안 적으면 Verilator/시뮬레이터가 **자동으로 bin을 나눠준다** (`auto_bin_max` 옵션으로 개수 조절). 근데 이건 "어떤 값이 의미 있는지"에 대한 설계자의 판단이 전혀 안 들어가므로, 이 프로젝트처럼 특정 경계값(wrap 버그가 났던 지점 등)이 중요한 경우엔 **직접 bins를 정의하는 게 훨씬 유용하다.**
- `illegal_bins`은 SVA의 assertion과 거의 같은 역할을 한다 — "이 값은 나오면 안 됨"을 coverage 쪽에서도 표현할 수 있다는 뜻. 다만 본질은 다르다: SVA는 매 순간의 규칙, illegal_bins는 "커버리지 샘플링 중 이 값이 걸리면 에러"이므로 보통은 SVA로 이미 잡고 있는 것과 겹치게 쓰기보다, coverage 쪽은 "정상 범위 안에서 어떤 값들을 시험했는가"에 집중하는 게 실전에서 더 흔하다.

### 3.3 Transition bins — 시퀀스 자체를 커버리지 대상으로

```systemverilog
coverpoint current_state {
    bins idle_to_load = (IDLE => LOAD_wgt);
    bins load_to_stream = (LOAD_wgt => STREAM);
    bins stream_to_idle = (STREAM => IDLE);
    bins full_cycle = (IDLE => LOAD_wgt => STREAM => IDLE);  // 여러 단계 연쇄도 가능
}
```

"이 상태값에 도달한 적이 있는가"뿐 아니라 "이 상태 전이(transition)가 실제로 일어난 적이 있는가"까지 확인할 수 있다. Controller FSM처럼 상태 전이 자체가 설계의 핵심인 모듈엔 이게 값(value) bin보다 더 의미있는 정보를 준다.

### 3.4 Cross coverage — 두 coverpoint의 "조합"을 확인

```systemverilog
covergroup cg_controller @(posedge clk);
    cp_state: coverpoint current_state { ... }
    cp_act_offset_boundary: coverpoint (act_offset == num_act) { bins hit = {1}; bins miss = {0}; }

    cross cp_state, cp_act_offset_boundary;
endgroup
```

`cross`는 "state=STREAM이면서 동시에 act_offset이 num_act에 정확히 도달한 순간이 실제로 있었는가"처럼, 각 coverpoint를 단독으로 볼 때는 안 보이는 **조합 시나리오**를 잡아준다. 개별 coverpoint는 다 100%인데 cross는 특정 조합만 비어있는 경우가 실전에서 꽤 흔하다 (예: `num_act`의 큰 값과 `inject_ena`가 자주 끊기는 상황이 동시에 발생한 적은 없는 경우).

### 3.5 자주 쓰는 `option`

```systemverilog
covergroup cg_name @(posedge clk);
    option.at_least = 1;      // 이 bin을 몇 번 이상 맞춰야 "커버됨"으로 칠지 (기본 1)
    option.goal = 100;        // 목표 커버리지 % (리포트에서 기준선으로 표시됨)
    ...
endgroup
```

이 프로젝트 규모에선 `at_least=1`(기본값)로 충분하다 — "한 번이라도 실제로 일어났는가"만 확인하면 됨.

---

## 4. 어디에 선언하나 — SVA와 똑같은 `bind` 패턴 재사용

SVA_Study_Guide.md 4절에서 썼던 방식을 그대로 가져오면 된다. covergroup도 그냥 모듈 안에 넣을 수 있는 하나의 구성 요소이므로, RTL을 건드리지 않고 별도 파일 + `bind`로 붙이면 된다.

```systemverilog
// sva/Controller_cov.sv — RTL은 전혀 수정하지 않음
module Controller_cov (
    input logic clk, rst_n,
    input logic [3:0] current_state,
    input logic [9:0] act_offset, num_act
);
    localparam IDLE = 3'b001, LOAD_wgt = 3'b010, STREAM = 3'b100;

    covergroup cg_controller @(posedge clk iff rst_n);
        cp_state: coverpoint current_state {
            bins idle      = {IDLE};
            bins load_wgt  = {LOAD_wgt};
            bins stream    = {STREAM};
        }
        cp_num_act: coverpoint num_act {
            bins small         = {[1:2]};
            bins wrap_boundary = {3, 4};
            bins large         = {[5:$]};
        }
        cross cp_state, cp_num_act;
    endgroup

    cg_controller cg_inst = new();
endmodule

// sva/bind.sv 에 한 줄 추가
bind Controller Controller_cov u_cov (
    .clk(clk), .rst_n(rst_n),
    .current_state(current_state),
    .act_offset(act_offset), .num_act(num_act)
);
```

`@(posedge clk iff rst_n)`처럼 clocking event에 `iff` 조건을 붙이면 리셋 중엔 샘플링을 건너뛴다 — SVA의 `disable iff (!rst_n)`과 같은 역할을 하는 covergroup 버전 문법이다.

---

## 5. 프로젝트 실전 예제 — 모듈별 추천 covergroup

### 5.1 Controller.sv — 위 4절 예제 그대로 사용

FSM 상태 자체의 coverage보다 **transition** coverage가 더 유용하다:

```systemverilog
cp_transitions: coverpoint current_state {
    bins t_idle_load   = (IDLE => LOAD_wgt);
    bins t_load_stream = (LOAD_wgt => STREAM);
    bins t_stream_idle = (STREAM => IDLE);
}
```

`num_act`는 2비트 wrap 버그가 났던 이력이 있으니(`act_offset` 폭이 `[1:0]`이었다가 `[9:0]`으로 고쳐진 사건, Notion 08/02 기록 참고), 그 근방 값(3, 4)을 별도 bin으로 명시해서 "그 경계를 실제로 테스트했는가"를 계속 추적하는 게 좋다.

### 5.2 FIFO_All.sv — credit counter의 경계값

```systemverilog
covergroup cg_fifo_all @(posedge clk iff rst_n);
    cp_counter: coverpoint counter {
        bins empty  = {0};
        bins mid    = {[1:7]};
        bins full   = {8};       // SVA의 p_counter_in_range가 지키는 바로 그 상한
    }
    cp_inject_pop: coverpoint {inject, pop_fire} {
        bins inject_only = {2'b10};
        bins pop_only     = {2'b01};
        bins both_same_cycle = {2'b11};  // 두 이벤트가 같은 클럭에 겹치는 경우 — 놓치기 쉬운 시나리오
        bins neither      = {2'b00};
    }
endgroup
```

`counter`가 8(full)에 실제로 도달해본 적이 있는지, `inject`와 `pop_fire`가 **같은 클럭에 동시에** 발생하는 경우까지 테스트했는지는 코드만 봐서는 알 수 없고 coverage로만 확인 가능하다. 이 동시 발생 케이스는 credit 카운터 로직에서 가장 버그가 나기 쉬운 지점이므로 우선순위가 높다.

### 5.3 SKEW_Unit.sv — 방금 고친 게이팅 로직과 직결

오늘 `act_skew_out`/`act_bubble`을 `valid_in` 기준으로 게이트하도록 고쳤다. 이 변경이 제대로 검증됐다고 말하려면, **"valid_in이 중간에 끊기는(gap) 상황"을 테스트에서 실제로 만들어봤는지**가 핵심이다. 계속 연속으로만(끊김 없이) `valid_in=1`을 넣는 테스트만 돌렸다면, 오늘 추가한 hold 로직(`valid_bubble[...] ? ... : ...`의 `else` 분기)은 단 한 번도 실행된 적이 없는 코드가 된다 — 이게 바로 coverage가 잡아주는 종류의 맹점이다.

```systemverilog
covergroup cg_skew @(posedge clk iff rst_n);
    // valid_in이 연속(1,1,1...)이었는지, 중간에 끊겼는지(1,0,1...)
    cp_valid_gap: coverpoint valid_in {
        bins rise_after_gap = (0 => 1);  // 끊겼다가 다시 시작 — else 분기(hold)가 실행됐다는 증거
        bins consecutive    = (1 => 1);  // 연속 주입
        bins fall           = (1 => 0);  // 끊기는 순간
    }
endgroup
```

`rise_after_gap` bin이 최소 한 번 hit돼야, "게이트가 실제로 값을 hold하는 상황"을 테스트가 다뤘다고 자신 있게 말할 수 있다. 지금 바로 이 covergroup부터 하나 만들어서 기존 테스트로 돌려보고, `rise_after_gap`이 비어있다면 그게 곧 "다음에 추가해야 할 테스트 케이스"를 정확히 알려주는 신호다.

---

## 6. Coverage 목표를 어떻게 잡나

100%를 무조건 목표로 삼는 건 오히려 비효율적일 수 있다. 이유:

- `illegal_bins`이나 애초에 설계상 도달 불가능한 조합(`cross`에서 자동 생성되는 조합 중 일부는 논리적으로 절대 안 나옴)은 100%에서 자연히 빠져야 하고, 이런 건 `ignore_bins`로 명시적으로 제외해줘야 리포트가 깨끗해진다.
- 반대로 "일단 bins를 다 채우기 위해 억지로 만든 테스트"는 실제 사용 시나리오와 무관한 시간 낭비가 될 수 있다.

실전에서 쓰는 루프는 이렇다: **테스트 실행 → coverage 리포트에서 비어있는 bin 확인 → "이게 실제로 있을 수 있는 시나리오인가?" 판단 → 있을 수 있으면 그 시나리오를 노리는 새 테스트 추가, 없을 수 있으면 ignore_bins로 명시적 제외 → 반복.** 이 프로젝트 규모에선 5절에서 정의한 coverpoint들이 전부 최소 1번씩 hit되는 걸 1차 목표로 삼으면 충분하다.

---

## 7. Verilator로 실행하기

Verilator는 5.050(2026-07-01 릴리스, SVA 가이드에서 쓴 것과 같은 버전)부터 covergroup/coverpoint/bins/cross를 정식으로 지원한다 — 이전엔 부분 지원 단계였는데 이번 릴리스로 상당히 완성됐다.

### 7.1 컴파일 시 플래그

```
verilator --binary --coverage --timing -Wall \
    --top-module tb_System \
    --Mdir build/verilator_obj \
    $(SRCS) $(SVAS) $(TB)
```

- `--coverage`: line/toggle/expression/covergroup/FSM coverage를 **전부** 켠다. 개별적으로만 켜고 싶으면 `--coverage-line`, `--coverage-toggle`, `--coverage-user`(covergroup 전용) 등으로 세분화 가능.
- 기존 `--assert`와는 별개의 플래그다 — SVA 검증(`test_sva` 타겟)과 coverage 수집(`test_cov` 같은 새 타겟)을 Makefile에 별도 타겟으로 나누는 걸 추천. 같이 켜도 상관은 없다.

### 7.2 실행하면 생기는 것

모델을 `--binary`로 빌드했다면, 테스트가 끝날 때 자동으로 coverage 데이터 파일을 남긴다 (`+verilator+coverage+file+<파일명>` 런타임 옵션으로 경로 지정, 기본은 `coverage.dat`).

### 7.3 리포트 보기

```
verilator_coverage --annotate build/cov_report coverage.dat
verilator_coverage --report summary coverage.dat
```

`--annotate`는 소스 코드에 커버리지 hit 카운트를 줄 단위로 달아서 보여준다 (SVA 가이드 스타일로 치면, `%`로 시작하는 줄이 "이 줄은 커버리지가 부족하다"는 표시). `--filter-type covergroup`을 추가하면 코드 커버리지(line/toggle)는 빼고 지금 만든 covergroup 결과만 골라볼 수 있다.

---

## 8. Verilator 관련 주의사항

- **FSM coverage(`--coverage-fsm`)는 아직 실험적 기능**이다(공식 문서에 명시). Controller의 state coverage는 여기서 배운 `covergroup`/`coverpoint` 방식(5.1절)으로 직접 선언하는 게 지금은 더 안정적이다 — 자동 FSM 추출 기능에 기대지 말 것.
- Toggle coverage는 "신호의 모든 비트가 0→1, 1→0을 다 겪었는가"를 자동으로 봐주는 것 — SRAM의 `mem` 배열처럼 아주 넓은 신호는 기본적으로 커버리지 대상에서 제외된다(256비트 초과, `--coverage-max-width`로 조절 가능). RAM/레지스터 파일류에 toggle coverage를 강제로 걸고 싶지 않으면 `/*verilator coverage_off*/` ~ `/*verilator coverage_on*/`로 감싸면 된다.
- covergroup도 SVA와 마찬가지로 `bind`로 붙이는 패턴이 자연스럽게 동작할 것으로 예상되지만, 이 프로젝트에서 아직 실제로 검증된 조합은 아니다 — SVA 때와 같은 전략(제일 단순한 covergroup 하나부터 컴파일 확인 → 점진적으로 cross/transition bins 추가)을 추천.
- `--coverage`를 켜면 시뮬레이션이 약간 느려진다(계측 코드가 추가되므로). 이 프로젝트 규모에선 체감될 정도는 아닐 것.
- reset 직후 몇 클럭 동안 신호가 안정화되며 발생하는 toggle이 잡음처럼 카운트될 수 있다는 점도 공식 문서가 언급한다 — 리셋 해제 직후에 커버리지를 0으로 초기화하는 것도 실전에서 흔한 습관이지만, 이 프로젝트 규모에선 큰 영향은 없을 것.

---

## 9. 학습 순서 제안 (직접 손으로 써보기)

1. 5.3절의 `cg_skew` covergroup을 그대로 `bind`로 붙여서 기존 `tb_Top_module.sv`/`tb_System.sv`로 돌려보기. `rise_after_gap` bin이 채워지는지 확인 — 아마 지금 테스트로는 안 채워질 가능성이 높다(연속 스트리밍 위주 테스트였으므로).
2. **직접 작성해보기**: `rise_after_gap`이 비어있다면, 그 bin을 채우는 새 테스트 시나리오를 직접 설계 — "STREAM 중간에 `inject_ena`를 몇 클럭 동안 0으로 내렸다가 다시 1로 올리는" 자극을 테스트벤치에 추가.
3. **직접 작성해보기**: FIFO_All의 `cp_inject_pop` covergroup(5.2절)을 만들어서, `both_same_cycle` bin이 실제로 채워지는지 확인. 안 채워진다면 이것도 2번과 같은 방식으로 자극을 설계해서 채워보기.
4. Controller의 `cross cp_state, cp_num_act`(5.1절)까지 작성해서, `verilator_coverage --report summary`로 전체 리포트를 한 번 뽑아보기.

---

## 10. 참고 자료

- [Verilator 5.050 Simulating — Coverage Analysis 공식 문서](https://verilator.org/guide/latest/simulating.html#coverage-analysis) — Property/Covergroup/FSM/Line/Toggle/Expression coverage 전체 개요, 1차 출처
- [Verilator 5.050 verilator_coverage 실행 파일 문서](https://verilator.org/guide/latest/exe_verilator_coverage.html) — `--annotate`, `--report`, `--filter-type` 등 옵션 레퍼런스
- [Verilator 5.050 릴리스 노트 (2026-07-01)](https://github.com/verilator/verilator-announce/issues/84) — covergroup/coverpoint/bins/cross 지원이 이 릴리스에 포함됨
- [ChipVerify — SystemVerilog Functional Coverage](https://chipverify.com/systemverilog/systemverilog-functional-coverage) — 문법 레퍼런스로 훑어보기 좋음 (SVA 가이드에서도 인용한 동일 사이트)
