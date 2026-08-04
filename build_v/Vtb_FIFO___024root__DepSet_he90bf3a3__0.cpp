// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_FIFO.h for the primary calling header

#include "Vtb_FIFO__pch.h"
#include "Vtb_FIFO___024root.h"

VlCoroutine Vtb_FIFO___024root___eval_initial__TOP__Vtiming__0(Vtb_FIFO___024root* vlSelf);
VlCoroutine Vtb_FIFO___024root___eval_initial__TOP__Vtiming__1(Vtb_FIFO___024root* vlSelf);

void Vtb_FIFO___024root___eval_initial(Vtb_FIFO___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb_FIFO__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_FIFO___024root___eval_initial\n"); );
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vtb_FIFO___024root___eval_initial__TOP__Vtiming__0(vlSelf);
    Vtb_FIFO___024root___eval_initial__TOP__Vtiming__1(vlSelf);
    vlSelfRef.__Vtrigprevexpr___TOP__tb_FIFO__DOT__clk__0 
        = vlSelfRef.tb_FIFO__DOT__clk;
}

VL_INLINE_OPT VlCoroutine Vtb_FIFO___024root___eval_initial__TOP__Vtiming__0(Vtb_FIFO___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb_FIFO__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_FIFO___024root___eval_initial__TOP__Vtiming__0\n"); );
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.tb_FIFO__DOT__clk = 0U;
    vlSelfRef.tb_FIFO__DOT__rst_n = 0U;
    vlSelfRef.tb_FIFO__DOT__wea = 0U;
    vlSelfRef.tb_FIFO__DOT__rea = 0U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         33);
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         33);
    vlSelfRef.tb_FIFO__DOT__rst_n = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         35);
    vlSelfRef.tb_FIFO__DOT__wea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         42);
    vlSelfRef.tb_FIFO__DOT__wea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         42);
    vlSelfRef.tb_FIFO__DOT__wea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         42);
    vlSelfRef.tb_FIFO__DOT__wea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         42);
    vlSelfRef.tb_FIFO__DOT__wea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         42);
    vlSelfRef.tb_FIFO__DOT__wea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         42);
    vlSelfRef.tb_FIFO__DOT__wea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         42);
    vlSelfRef.tb_FIFO__DOT__wea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         42);
    vlSelfRef.tb_FIFO__DOT__wea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         42);
    vlSelfRef.tb_FIFO__DOT__wea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         42);
    vlSelfRef.tb_FIFO__DOT__wea = 0U;
    vlSelfRef.tb_FIFO__DOT__rea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         50);
    vlSelfRef.tb_FIFO__DOT__rea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         50);
    vlSelfRef.tb_FIFO__DOT__rea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         50);
    vlSelfRef.tb_FIFO__DOT__rea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         50);
    vlSelfRef.tb_FIFO__DOT__rea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         50);
    vlSelfRef.tb_FIFO__DOT__rea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         50);
    vlSelfRef.tb_FIFO__DOT__rea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         50);
    vlSelfRef.tb_FIFO__DOT__rea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         50);
    vlSelfRef.tb_FIFO__DOT__rea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         50);
    vlSelfRef.tb_FIFO__DOT__rea = 1U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         50);
    vlSelfRef.tb_FIFO__DOT__rea = 0U;
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         54);
    co_await vlSelfRef.__VtrigSched_hb3e018ce__0.trigger(0U, 
                                                         nullptr, 
                                                         "@(posedge tb_FIFO.clk)", 
                                                         "tb/tb_FIFO.sv", 
                                                         54);
    VL_WRITEF_NX("tb_FIFO: done, no assertion failures above means PASS\n",0);
    VL_FINISH_MT("tb/tb_FIFO.sv", 56, "");
}

VL_INLINE_OPT VlCoroutine Vtb_FIFO___024root___eval_initial__TOP__Vtiming__1(Vtb_FIFO___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb_FIFO__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_FIFO___024root___eval_initial__TOP__Vtiming__1\n"); );
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    while (1U) {
        co_await vlSelfRef.__VdlySched.delay(0x1388ULL, 
                                             nullptr, 
                                             "tb/tb_FIFO.sv", 
                                             24);
        vlSelfRef.tb_FIFO__DOT__clk = (1U & (~ (IData)(vlSelfRef.tb_FIFO__DOT__clk)));
    }
}

void Vtb_FIFO___024root___eval_act(Vtb_FIFO___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb_FIFO__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_FIFO___024root___eval_act\n"); );
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

void Vtb_FIFO___024root___nba_sequent__TOP__0(Vtb_FIFO___024root* vlSelf);

void Vtb_FIFO___024root___eval_nba(Vtb_FIFO___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb_FIFO__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_FIFO___024root___eval_nba\n"); );
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VnbaTriggered.word(0U))) {
        Vtb_FIFO___024root___nba_sequent__TOP__0(vlSelf);
    }
}

void Vtb_FIFO___024root___timing_resume(Vtb_FIFO___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb_FIFO__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_FIFO___024root___timing_resume\n"); );
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VactTriggered.word(0U))) {
        vlSelfRef.__VtrigSched_hb3e018ce__0.resume(
                                                   "@(posedge tb_FIFO.clk)");
    }
    if ((2ULL & vlSelfRef.__VactTriggered.word(0U))) {
        vlSelfRef.__VdlySched.resume();
    }
}

void Vtb_FIFO___024root___timing_commit(Vtb_FIFO___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb_FIFO__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_FIFO___024root___timing_commit\n"); );
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((! (1ULL & vlSelfRef.__VactTriggered.word(0U)))) {
        vlSelfRef.__VtrigSched_hb3e018ce__0.commit(
                                                   "@(posedge tb_FIFO.clk)");
    }
}

void Vtb_FIFO___024root___eval_triggers__act(Vtb_FIFO___024root* vlSelf);

bool Vtb_FIFO___024root___eval_phase__act(Vtb_FIFO___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb_FIFO__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_FIFO___024root___eval_phase__act\n"); );
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Init
    VlTriggerVec<2> __VpreTriggered;
    CData/*0:0*/ __VactExecute;
    // Body
    Vtb_FIFO___024root___eval_triggers__act(vlSelf);
    Vtb_FIFO___024root___timing_commit(vlSelf);
    __VactExecute = vlSelfRef.__VactTriggered.any();
    if (__VactExecute) {
        __VpreTriggered.andNot(vlSelfRef.__VactTriggered, vlSelfRef.__VnbaTriggered);
        vlSelfRef.__VnbaTriggered.thisOr(vlSelfRef.__VactTriggered);
        Vtb_FIFO___024root___timing_resume(vlSelf);
        Vtb_FIFO___024root___eval_act(vlSelf);
    }
    return (__VactExecute);
}

bool Vtb_FIFO___024root___eval_phase__nba(Vtb_FIFO___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb_FIFO__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_FIFO___024root___eval_phase__nba\n"); );
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Init
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = vlSelfRef.__VnbaTriggered.any();
    if (__VnbaExecute) {
        Vtb_FIFO___024root___eval_nba(vlSelf);
        vlSelfRef.__VnbaTriggered.clear();
    }
    return (__VnbaExecute);
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_FIFO___024root___dump_triggers__nba(Vtb_FIFO___024root* vlSelf);
#endif  // VL_DEBUG
#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_FIFO___024root___dump_triggers__act(Vtb_FIFO___024root* vlSelf);
#endif  // VL_DEBUG

void Vtb_FIFO___024root___eval(Vtb_FIFO___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb_FIFO__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_FIFO___024root___eval\n"); );
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Init
    vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__rst_n = vlSelfRef.tb_FIFO__DOT__rst_n;
    vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__ff_empty 
        = vlSelfRef.tb_FIFO__DOT__ff_empty;
    vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__ff_full 
        = vlSelfRef.tb_FIFO__DOT__ff_full;
    vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_0_0 
        = vlSelfRef.tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_0_0;
    vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_1_0 
        = vlSelfRef.tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_1_0;
    vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__wr_ptr 
        = vlSelfRef.tb_FIFO__DOT__DUT__DOT__wr_ptr;
    vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_2_0 
        = vlSelfRef.tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_2_0;
    vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_3_0 
        = vlSelfRef.tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_3_0;
    vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__rd_ptr 
        = vlSelfRef.tb_FIFO__DOT__DUT__DOT__rd_ptr;
    vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__wea = vlSelfRef.tb_FIFO__DOT__wea;
    vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__rea = vlSelfRef.tb_FIFO__DOT__rea;
    IData/*31:0*/ __VnbaIterCount;
    CData/*0:0*/ __VnbaContinue;
    // Body
    __VnbaIterCount = 0U;
    __VnbaContinue = 1U;
    while (__VnbaContinue) {
        if (VL_UNLIKELY((0x64U < __VnbaIterCount))) {
#ifdef VL_DEBUG
            Vtb_FIFO___024root___dump_triggers__nba(vlSelf);
#endif
            VL_FATAL_MT("tb/tb_FIFO.sv", 3, "", "NBA region did not converge.");
        }
        __VnbaIterCount = ((IData)(1U) + __VnbaIterCount);
        __VnbaContinue = 0U;
        vlSelfRef.__VactIterCount = 0U;
        vlSelfRef.__VactContinue = 1U;
        while (vlSelfRef.__VactContinue) {
            if (VL_UNLIKELY((0x64U < vlSelfRef.__VactIterCount))) {
#ifdef VL_DEBUG
                Vtb_FIFO___024root___dump_triggers__act(vlSelf);
#endif
                VL_FATAL_MT("tb/tb_FIFO.sv", 3, "", "Active region did not converge.");
            }
            vlSelfRef.__VactIterCount = ((IData)(1U) 
                                         + vlSelfRef.__VactIterCount);
            vlSelfRef.__VactContinue = 0U;
            if (Vtb_FIFO___024root___eval_phase__act(vlSelf)) {
                vlSelfRef.__VactContinue = 1U;
            }
        }
        if (Vtb_FIFO___024root___eval_phase__nba(vlSelf)) {
            __VnbaContinue = 1U;
        }
    }
}

#ifdef VL_DEBUG
void Vtb_FIFO___024root___eval_debug_assertions(Vtb_FIFO___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb_FIFO__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_FIFO___024root___eval_debug_assertions\n"); );
    auto& vlSelfRef = std::ref(*vlSelf).get();
}
#endif  // VL_DEBUG
