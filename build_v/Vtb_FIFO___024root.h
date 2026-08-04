// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vtb_FIFO.h for the primary calling header

#ifndef VERILATED_VTB_FIFO___024ROOT_H_
#define VERILATED_VTB_FIFO___024ROOT_H_  // guard

#include "verilated.h"
#include "verilated_timing.h"


class Vtb_FIFO__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vtb_FIFO___024root final : public VerilatedModule {
  public:

    // DESIGN SPECIFIC STATE
    CData/*0:0*/ tb_FIFO__DOT__clk;
    CData/*0:0*/ tb_FIFO__DOT__rst_n;
    CData/*0:0*/ tb_FIFO__DOT__wea;
    CData/*0:0*/ tb_FIFO__DOT__rea;
    CData/*0:0*/ tb_FIFO__DOT__ff_empty;
    CData/*0:0*/ tb_FIFO__DOT__ff_full;
    CData/*3:0*/ tb_FIFO__DOT__DUT__DOT__wr_ptr;
    CData/*3:0*/ tb_FIFO__DOT__DUT__DOT__rd_ptr;
    CData/*0:0*/ tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_0_0;
    CData/*3:0*/ tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_1_0;
    CData/*0:0*/ tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_2_0;
    CData/*3:0*/ tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_3_0;
    CData/*0:0*/ __Vsampled_TOP__tb_FIFO__DOT__rst_n;
    CData/*0:0*/ __Vsampled_TOP__tb_FIFO__DOT__ff_empty;
    CData/*0:0*/ __Vsampled_TOP__tb_FIFO__DOT__ff_full;
    CData/*0:0*/ __Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_0_0;
    CData/*3:0*/ __Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_1_0;
    CData/*3:0*/ __Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__wr_ptr;
    CData/*0:0*/ __Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_2_0;
    CData/*3:0*/ __Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__fifo_sva_inst__DOT___Vpast_3_0;
    CData/*3:0*/ __Vsampled_TOP__tb_FIFO__DOT__DUT__DOT__rd_ptr;
    CData/*0:0*/ __Vsampled_TOP__tb_FIFO__DOT__wea;
    CData/*0:0*/ __Vsampled_TOP__tb_FIFO__DOT__rea;
    CData/*0:0*/ __VstlFirstIteration;
    CData/*0:0*/ __Vtrigprevexpr___TOP__tb_FIFO__DOT__clk__0;
    CData/*0:0*/ __VactContinue;
    IData/*31:0*/ __VactIterCount;
    VlDelayScheduler __VdlySched;
    VlTriggerScheduler __VtrigSched_hb3e018ce__0;
    VlTriggerVec<1> __VstlTriggered;
    VlTriggerVec<2> __VactTriggered;
    VlTriggerVec<2> __VnbaTriggered;

    // INTERNAL VARIABLES
    Vtb_FIFO__Syms* const vlSymsp;

    // CONSTRUCTORS
    Vtb_FIFO___024root(Vtb_FIFO__Syms* symsp, const char* v__name);
    ~Vtb_FIFO___024root();
    VL_UNCOPYABLE(Vtb_FIFO___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
