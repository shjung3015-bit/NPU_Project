# SystemVerilog Assertion (SVA) 스터디 가이드

> NPU_Project (Weight-Stationary Systolic Array) Phase 2 검증 역량 보강용.
> 개념 → 문법 → 실제 프로젝트 코드(Controller / FIFO / FIFO_All / SRAM) 적용 순서로 구성.
> 2026.08.03 작성.

---

## 1. Assertion이 왜 필요한가

지금까지 검증 방식은 self-checking testbench(golden model과 비교)였다. 이 방식은 **"최종 출력이 맞는가"**만 본다. 반면 assertion은 **"중간 과정에서 지켜야 할 규칙이 매 순간 지켜지는가"**를 본다.

이번 프로젝트에서 이미 겪은 버그들을 돌아보면:

- FIFO_All의 `output_valid`가 실제 데이터보다 1클럭 먼저 뜨는 버그 → 최종 출력만 비교하는 golden model 테스트로는 우연히 통과할 수도 있었다. "output_valid는 반드시 pop_fire의 정확히 1클럭 뒤에만 뜬다"는 타이밍 규칙을 assertion으로 박아두면 즉시 잡힌다.
- Controller의 state 레지스터 폭 버그(4비트에 5비트 값을 넣어 DONE이 잘림) → "current_state는 항상 legal한 값 중 하나여야 한다"는 assertion 하나로 첫 클럭에 바로 잡혔을 문제.

즉 assertion은 **버그가 golden model 비교까지 전파되기 전에, 발생한 그 자리에서 바로 잡아내는** 용도다. 디버깅 시간을 몇 시간에서 몇 초로 줄여주는 게 핵심 가치.

---

## 2. 가장 중요한 구분: Immediate vs Concurrent

### 2.1 Immediate assertion

`if`문처럼 그 순간의 값만 확인한다. 클럭 개념이 없고, procedural block(`always_ff`, `always_comb`, `initial` 등) 안에서만 쓴다.

```systemverilog
always_ff @(posedge clk) begin
    if (rst_n) begin
        assert (!(ff_full && ff_empty))
        else $error("FIFO full/empty 동시 참");
    end
end
```

지금 하는 golden model 비교(`if (result !== expected) ...`)와 본질적으로 같은 카테고리다. 차이는 `assert`가 시뮬레이터의 표준화된 실패 리포팅(카운트, 메시지 포맷)을 공짜로 준다는 것.

### 2.2 Concurrent assertion

**시간에 걸쳐** 성립해야 하는 규칙을 표현한다. 클럭에 동기화되어 매 클럭 평가된다. `property`/`assert property`로 작성하며, 오늘 배울 내용의 핵심.

```systemverilog
// "output_valid는 pop_fire가 뜬 정확히 1클럭 뒤에만 뜬다"
property p_output_valid_timing;
    @(posedge clk) disable iff (!rst_n)
    pop_fire |=> output_valid;
endproperty

assert property (p_output_valid_timing)
else $error("output_valid 타이밍 어긋남");
```

Immediate로는 "지금 이 값이 맞다/틀리다"만 볼 수 있지만, concurrent는 "N클럭 전에 이런 일이 있었으면 지금 이래야 한다" 같은 **시간 관계**를 선언적으로 표현한다. FIFO_All의 버그처럼 클럭 지연이 얽힌 문제엔 concurrent가 훨씬 자연스럽다.

---

## 3. Concurrent Assertion 문법 뼈대

```systemverilog
property <이름>;
    @(posedge clk) disable iff (!rst_n)
    <선행조건> |-> <후행조건>;
endproperty

assert property (<이름>)
else $error("<메시지>");
```

각 조각의 의미:

- `@(posedge clk)` — 이 property를 평가할 클럭. 대부분의 경우 설계의 메인 클럭과 동일.
- `disable iff (!rst_n)` — 리셋 중에는 평가 자체를 하지 않음. **거의 항상 필요** — 리셋 중엔 신호가 정의되지 않은 과도 상태라 대부분의 규칙이 일시적으로 깨지기 때문. 조합 논리는 리셋이 필요 없다는 원칙(이미 알고 있는 것)과 같은 맥락에서, "리셋 중엔 규칙 검사도 잠시 꺼둔다"고 이해하면 됨.
- `|->` / `|=>` — 임플리케이션(implication). 아래 4절에서 자세히.

### 3.1 `|->` vs `|=>` (overlapping vs non-overlapping)

이게 SVA에서 제일 헷갈리는 부분이자 제일 중요한 부분이다.

- `a |-> b` : **같은 클럭**에 a가 참이면 b도 참이어야 함 (overlapping)
- `a |=> b` : a가 참인 **다음 클럭**에 b가 참이어야 함 (non-overlapping, `a |-> ##1 b`와 동일)

Controller 예로 보면:

```systemverilog
// "LOAD_wgt 상태에 있으면(같은 클럭) enb_wgt는 항상 1이다" — 같은 클럭 비교이므로 |->
property p_enb_wgt_matches_state;
    @(posedge clk) disable iff (!rst_n)
    (current_state == LOAD_wgt) |-> enb_wgt;
endproperty
```

```systemverilog
// "STREAM 상태에서 inject_ena && act_offset<num_act 조건이 참이었으면,
//  그 다음 클럭에 start가 1이어야 한다" — 조건이 관측된 다음 클럭 얘기이므로 |=>
property p_start_after_inject;
    @(posedge clk) disable iff (!rst_n)
    ((current_state == STREAM) && inject_ena && (act_offset < num_act)) |=> start;
endproperty
```

이 둘의 차이를 처음엔 계속 헷갈릴 텐데, "**지금 당장**이면 `|->`, **한 박자 쉬고**면 `|=>`"로 외워두면 됨.

### 3.2 Sequence 연산자 — 시간 구간을 표현하기

- `##1` : 정확히 1클럭 뒤
- `##[2:4]` : 2~4클럭 사이 아무 때나
- `##[1:$]` : 1클럭 이후 아무 때나 (무한대, `$`는 "제한 없음")
- `throughout` : 어떤 구간 동안 계속 참이어야 함
- `within` : 한 시퀀스가 다른 시퀀스 구간 안에 포함되는지

실전에서는 `throughout`/`within`/`first_match`보다 `##N` + `|->`/`|=>` 조합만으로 이 프로젝트의 대부분의 규칙을 표현할 수 있다. 고급 연산자는 나중에 여유 생기면 익히는 걸 추천 (Verilator 지원이 더 불안정한 영역이기도 함, 8절 참고).

### 3.3 유용한 system function

| 함수 | 의미 |
|---|---|
| `$past(expr, N)` | N클럭 전의 expr 값 (기본 N=1) |
| `$stable(expr)` | 지난 클럭과 값이 같으면 참 |
| `$rose(expr)` | 0→1로 막 바뀌었으면 참 |
| `$fell(expr)` | 1→0으로 막 바뀌었으면 참 |
| `$onehot(expr)` | 정확히 비트 하나만 1이면 참 |
| `$onehot0(expr)` | 1인 비트가 0개 또는 1개면 참 |
| `$isunknown(expr)` | X/Z 포함되어 있으면 참 (Verilator는 2-state라 제한적, 8절 참고) |
| `$countones(expr)` | 1인 비트 개수 |

Controller의 state가 정확히 one-hot이어야 한다는 걸 이렇게 표현:

```systemverilog
property p_state_is_legal_onehot;
    @(posedge clk) disable iff (!rst_n)
    $onehot(current_state[2:0]); // IDLE/LOAD_wgt/STREAM = 3'b001/010/100
endproperty
```

---

## 4. `bind`로 RTL을 안 건드리고 assertion 붙이기

지금 파일 구조(`src/Controller.sv` 등)를 그대로 두고, 검증 코드는 별도 파일로 분리하는 게 좋다. 실무에서도 assertion은 보통 RTL과 분리해서 관리한다.

```systemverilog
// src/Controller_sva.sv — 새 파일, RTL은 전혀 수정하지 않음
module Controller_sva (
    input logic clk, rst_n,
    input logic [3:0] current_state,
    input logic enb_wgt, enb_act, load_en, start,
    input logic [9:0] act_offset, num_act
);
    localparam IDLE = 3'b001, LOAD_wgt = 3'b010, STREAM = 3'b100;

    property p_state_is_legal_onehot;
        @(posedge clk) disable iff (!rst_n)
        $onehot(current_state[2:0]);
    endproperty
    assert property (p_state_is_legal_onehot)
    else $error("[Controller] current_state가 legal 값이 아님: %b", current_state);

    property p_enb_wgt_matches_state;
        @(posedge clk) disable iff (!rst_n)
        (current_state == LOAD_wgt) |-> enb_wgt;
    endproperty
    assert property (p_enb_wgt_matches_state)
    else $error("[Controller] LOAD_wgt인데 enb_wgt=0");

    property p_load_en_start_exclusive;
        @(posedge clk) disable iff (!rst_n)
        !(load_en && start); // 두 신호가 동시에 뜨면 안 됨 (weight load와 streaming은 배타적 단계)
    endproperty
    assert property (p_load_en_start_exclusive)
    else $error("[Controller] load_en과 start가 동시에 1임");

endmodule

// tb 어딘가, 혹은 별도 bind 파일에:
bind Controller Controller_sva u_sva (
    .clk(clk), .rst_n(rst_n),
    .current_state(current_state),
    .enb_wgt(enb_wgt), .enb_act(enb_act),
    .load_en(load_en), .start(start),
    .act_offset(act_offset), .num_act(num_act)
);
```

`bind`는 지정한 모듈(`Controller`)의 모든 인스턴스에 자동으로 이 assertion 모듈을 꽂아준다. 시뮬레이션에만 존재하고 실제 합성 대상 RTL에는 전혀 영향을 주지 않는다. (주의: Verilator는 target을 모듈 이름으로만 bind 가능 — 인스턴스 경로 지정 bind는 미지원. 이 프로젝트처럼 모듈당 인스턴스가 하나뿐이면 문제 없음.)

---

## 5. 프로젝트 실전 예제 — 모듈별 추천 assertion 세트

### 5.1 Controller.sv

```systemverilog
// wgt_offset이 0에 도달하면 다음 클럭엔 반드시 LOAD_wgt를 벗어난다
property p_wgt_offset_in_load_stops_at_zero;
    @(posedge clk) disable iff (!rst_n)
    (current_state == LOAD_wgt) && (wgt_offset == 2'b00) |=> (current_state != LOAD_wgt);
endproperty

// STREAM은 act_offset이 num_act에 도달하면 다음 클럭 반드시 벗어난다
property p_stream_exits_at_num_act;
    @(posedge clk) disable iff (!rst_n)
    (current_state == STREAM) && (act_offset == num_act) |=> (current_state != STREAM);
endproperty
```

### 5.2 SRAM.sv — registered read latency 자체를 assertion화

이전에 두 번이나 이 타이밍 때문에 버그가 났었다(`enb`가 `addr`보다 늦게 켜져서 값이 유실됨). 이 관계를 assertion으로 박아두면 앞으로 SRAM 근처를 건드릴 때마다 자동으로 지켜지는지 체크된다.

```systemverilog
// enb가 뜬 클럭으로부터 정확히 1클럭 뒤에 dout이 그때의 mem[addr_rd] 값과 같아야 한다
property p_registered_read_latency;
    @(posedge clk)
    enb |=> (dout == $past(mem[addr_rd]));
endproperty
assert property (p_registered_read_latency)
else $error("[SRAM] read latency 어긋남");
```

주의: `mem`은 내부 배열이라 외부 assertion 모듈에서 직접 참조하려면 같은 모듈 내부에 두거나(`bind`로 붙이면 내부 신호 접근 가능), Verilator에서 배열 원소 단위 `$past()`가 지원되는지 먼저 작은 예제로 확인해볼 것 (8절).

### 5.3 FIFO.sv

```systemverilog
// full과 empty가 동시에 참일 수 없음
property p_fifo_not_full_and_empty;
    @(posedge clk) disable iff (!rst_n)
    !(ff_full && ff_empty);
endproperty

// full일 때 write 시도가 있어도 wr_ptr은 절대 증가하면 안 됨 (오버플로우로 데이터 덮어쓰기 방지 확인)
property p_no_write_when_full;
    @(posedge clk) disable iff (!rst_n)
    (wea && ff_full) |=> $stable(wr_ptr);
endproperty

// empty일 때 read 시도가 있어도 rd_ptr은 절대 증가하면 안 됨
property p_no_read_when_empty;
    @(posedge clk) disable iff (!rst_n)
    (rea && ff_empty) |=> $stable(rd_ptr);
endproperty
```

### 5.4 FIFO_All.sv — 이전에 실제로 겪은 두 버그를 그대로 assertion화

```systemverilog
// counter는 [0, 8] 범위를 절대 벗어나면 안 됨 (credit 흐름제어의 핵심 불변식)
property p_counter_in_range;
    @(posedge clk) disable iff (!rst_n)
    (counter <= 9'd8);
endproperty

// 바로 그 버그: output_valid는 pop_fire의 정확히 1클럭 뒤에만 뜬다 (동시가 아님)
property p_output_valid_lags_pop_fire_by_1;
    @(posedge clk) disable iff (!rst_n)
    pop_fire |=> output_valid;
endproperty

property p_output_valid_only_after_pop_fire;
    @(posedge clk) disable iff (!rst_n)
    output_valid |-> $past(pop_fire);
endproperty

// 4개 컬럼은 반드시 0→1→2→3 순서로, 한 클럭 간격으로만 떠야 함 (역전 불가)
property p_column_order;
    @(posedge clk) disable iff (!rst_n)
    data_valid[0] |=> ##1 data_valid[1] ##1 data_valid[2] ##1 data_valid[3];
endproperty
```

---

## 6. Functional Coverage — SVA와 짝을 이루는 도구 (짧은 예고편)

SVA는 "규칙 위반을 잡는" 도구, `covergroup`은 "의미 있는 시나리오를 실제로 다 실행해봤는지 확인하는" 도구. 오늘은 SVA에 집중하되, 문법만 미리 감 잡아두면 좋다:

```systemverilog
covergroup cg_num_act @(posedge clk);
    cp_num_act: coverpoint num_act {
        bins small   = {[1:2]};
        bins wrap_boundary = {3, 4}; // 예전 2비트 wrap 버그가 났던 경계
        bins large   = {[5:$]};
    }
endgroup
```

이건 다음 세션에서 별도로 깊게 다루자.

---

## 7. 학습 순서 제안 (직접 손으로 써보기)

1. 위 5.3(FIFO) 예제 두 개를 그대로 `bind`로 붙여서 컴파일까지 해보기 — 문법 자체에 익숙해지는 게 목표.
2. **직접 작성해보기**: MAC_Unit.sv에 대해 "load_en이 뜬 다음 클럭엔 w_reg가 그때의 w_in 값과 같아야 한다"는 property를 스스로 작성. (`$past` 사용)
3. **직접 작성해보기**: SKEW_Unit.sv에 대해 "valid_in이 뜨면 정확히 3클럭 뒤에 valid_out[3]이 떠야 한다"는 property 작성. (`##3` 사용, 이미 알고 있는 skew depth 지식을 그대로 시간 관계로 옮기는 연습)
4. 위 3개를 다 작성한 뒤 Verilator로 컴파일 — 에러 나면 8절 참고해서 원인이 "내 문법 실수"인지 "Verilator 미지원"인지 구분.

---

## 8. Verilator로 실행할 때 주의사항

- Verilator의 SVA 지원은 **공식 문서에서도 "partially supports"라고 명시**되어 있음 — 전체 SVA 스펙 대비 부분 구현. 최신 5.050(2026.07 릴리스)에서 `assert property ... default disable iff`가 개선되는 등 계속 발전 중.
- 기본적인 `assert property (@(posedge clk) disable iff(!rst_n) a |-> b)`, `##N` 딜레이는 실전에서 널리 쓰이고 잘 동작하는 편이지만, 별도로 선언한 `sequence ... endsequence` / `property` 재사용, `first_match`, `throughout`/`within` 조합, `assume` 등 고급 구문은 버전에 따라 지원이 들쭉날쭉함.
- **전략**: 복잡한 property는 처음부터 한 번에 쓰지 말고, 제일 단순한 형태(`a |-> b`)부터 컴파일 확인 → 점진적으로 `##N`, `disable iff` 등을 추가하며 어디서 막히는지 확인. 컴파일 에러가 나면 "내가 SVA 문법을 잘못 쓴 건지" vs "Verilator가 이 구문을 아직 지원 안 하는 건지"를 Verilator 에러 메시지로 구분(보통 `%Error: Unsupported` 형태로 명확히 알려줌).
- 안 되는 구문을 만나면 억지로 우회하지 말고, 같은 규칙을 **immediate assertion + `always_ff`**로 재작성하는 것도 실전에서 흔한 타협책. (예: `##3` 시퀀스가 안 먹히면 직접 3단 shift register로 지연시킨 신호를 immediate assertion으로 비교)
- Verilator는 기본적으로 2-state 시뮬레이터라 `$isunknown` 등 X 관련 체크는 4-state 시뮬레이터(Xcelium 등)만큼 신뢰도가 높지 않음 — 이 프로젝트 규모에선 크게 문제 되지 않지만 알아둘 것.
- 실행 시 `--assert` 플래그로 assertion 체크를 켜야 함 (`--coverage`는 커버리지용, 별개 플래그).

---

## 9. 참고 자료

- [Verilator 5.050 Input Languages 공식 문서](https://verilator.org/guide/latest/languages.html) — Assertions/Coverage 지원 범위의 1차 출처
- [Verilator 5.050 릴리스 노트](https://github.com/verilator/verilator-announce/issues/84)
- [ChipVerify — SystemVerilog Assertions](https://www.chipverify.com/systemverilog/systemverilog-assertions) — 문법 레퍼런스로 훑어보기 좋음
- [ChipVerify — SystemVerilog Functional Coverage](https://chipverify.com/systemverilog/systemverilog-functional-coverage)
