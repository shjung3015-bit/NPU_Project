// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_FIFO.h for the primary calling header

#include "Vtb_FIFO__pch.h"
#include "Vtb_FIFO__Syms.h"
#include "Vtb_FIFO___024root.h"

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_FIFO___024root___dump_triggers__act(Vtb_FIFO___024root* vlSelf);
#endif  // VL_DEBUG

void Vtb_FIFO___024root___eval_triggers__act(Vtb_FIFO___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb_FIFO__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_FIFO___024root___eval_triggers__act\n"); );
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VactTriggered.set(0U, ((IData)(vlSelfRef.tb_FIFO__DOT__clk) 
                                       & (~ (IData)(vlSelfRef.__Vtrigprevexpr___TOP__tb_FIFO__DOT__clk__0))));
    vlSelfRef.__VactTriggered.set(1U, vlSelfRef.__VdlySched.awaitingCurrentTime());
    vlSelfRef.__Vtrigprevexpr___TOP__tb_FIFO__DOT__clk__0 
        = vlSelfRef.tb_FIFO__DOT__clk;
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb_FIFO___024root___dump_triggers__act(vlSelf);
    }
#endif
}

VL_INLINE_OPT void Vtb_FIFO___024root___nba_sequent__TOP__0(Vtb_FIFO___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb_FIFO__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_FIFO___024root___nba_sequent__TOP__0\n"); );
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if (vlSymsp->_vm_contextp__->assertOnGet(1, 1)) {
        if (VL_UNLIKELY((1U & (~ ((~ (IData)(vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__rst_n)) 
                                  | (~ ((IData)(vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__ff_empty) 
                                        & (IData)(vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__ff_full)))))))) {
            VL_WRITEF_NX("[%0t] %%Error: FIFO_sva.sv:13: Assertion failed in %Ntb_FIFO.DUT.fifo_sva_inst: FIFO cannot be empty and full at the same time\n",0,
                         64,VL_TIME_UNITED_Q(1000),
                         -9,vlSymsp->name());
            VL_STOP_MT("sva/FIFO_sva.sv", 13, "");
        }
    }
    if (vlSymsp->_vm_contextp__->assertOnGet(1, 1)) {
        if (VL_UNLIKELY((1U & (~ ((~ (IData)(vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__rst_n)) 
                                  | ((~ (IData)(vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_0_0)) 
                                     | ((IData)(vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_1_0) 
                                        == (IData)(vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__wr_ptr)))))))) {
            VL_WRITEF_NX("[%0t] %%Error: FIFO_sva.sv:20: Assertion failed in %Ntb_FIFO.DUT.fifo_sva_inst: FIFO cannot write when full\n",0,
                         64,VL_TIME_UNITED_Q(1000),
                         -9,vlSymsp->name());
            VL_STOP_MT("sva/FIFO_sva.sv", 20, "");
        }
    }
    if (vlSymsp->_vm_contextp__->assertOnGet(1, 1)) {
        if (VL_UNLIKELY((1U & (~ ((~ (IData)(vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__rst_n)) 
                                  | ((~ (IData)(vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_2_0)) 
                                     | ((IData)(vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_3_0) 
                                        == (IData)(vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__rd_ptr)))))))) {
            VL_WRITEF_NX("[%0t] %%Error: FIFO_sva.sv:27: Assertion failed in %Ntb_FIFO.DUT.fifo_sva_inst: FIFO cannot read when empty\n",0,
                         64,VL_TIME_UNITED_Q(1000),
                         -9,vlSymsp->name());
            VL_STOP_MT("sva/FIFO_sva.sv", 27, "");
        }
    }
    if (vlSelfRef.tb_FIFO__DOT__rst_n) {
        vlSelfRef.tb_FIFO__DOT__DUT__DOT__wr_ptr = 
            (0xfU & (((IData)(vlSelfRef.tb_FIFO__DOT__wea) 
                      & (~ (IData)(vlSelfRef.tb_FIFO__DOT__ff_full)))
                      ? ((IData)(1U) + (IData)(vlSelfRef.tb_FIFO__DOT__DUT__DOT__wr_ptr))
                      : (IData)(vlSelfRef.tb_FIFO__DOT__DUT__DOT__wr_ptr)));
        vlSelfRef.tb_FIFO__DOT__DUT__DOT__rd_ptr = 
            (0xfU & (((IData)(vlSelfRef.tb_FIFO__DOT__rea) 
                      & (~ (IData)(vlSelfRef.tb_FIFO__DOT__ff_empty)))
                      ? ((IData)(1U) + (IData)(vlSelfRef.tb_FIFO__DOT__DUT__DOT__rd_ptr))
                      : (IData)(vlSelfRef.tb_FIFO__DOT__DUT__DOT__rd_ptr)));
    } else {
        vlSelfRef.tb_FIFO__DOT__DUT__DOT__wr_ptr = 0U;
        vlSelfRef.tb_FIFO__DOT__DUT__DOT__rd_ptr = 0U;
    }
    vlSelfRef.tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_1_0 
        = vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__wr_ptr;
    vlSelfRef.tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_3_0 
        = vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__rd_ptr;
    vlSelfRef.tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_0_0 
        = ((IData)(vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__rst_n) 
           & ((IData)(vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__wea) 
              & (IData)(vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__ff_full)));
    vlSelfRef.tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_2_0 
        = ((IData)(vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__rst_n) 
           & ((IData)(vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__rea) 
              & (IData)(vlSelfRef.__Vsampled_TOP__tb_FIFO__DOT__ff_empty)));
    vlSelfRef.tb_FIFO__DOT__ff_empty = ((IData)(vlSelfRef.tb_FIFO__DOT__DUT__DOT__rd_ptr) 
                                        == (IData)(vlSelfRef.tb_FIFO__DOT__DUT__DOT__wr_ptr));
    vlSelfRef.tb_FIFO__DOT__ff_full = (((7U & (IData)(vlSelfRef.tb_FIFO__DOT__DUT__DOT__wr_ptr)) 
                                        == (7U & (IData)(vlSelfRef.tb_FIFO__DOT__DUT__DOT__rd_ptr))) 
                                       & ((1U & ((IData)(vlSelfRef.tb_FIFO__DOT__DUT__DOT__wr_ptr) 
                                                 >> 3U)) 
                                          != (1U & 
                                              ((IData)(vlSelfRef.tb_FIFO__DOT__DUT__DOT__rd_ptr) 
                                               >> 3U))));
}
