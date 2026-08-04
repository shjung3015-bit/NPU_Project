// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_FIFO.h for the primary calling header

#include "Vtb_FIFO__pch.h"
#include "Vtb_FIFO__Syms.h"
#include "Vtb_FIFO___024root.h"

void Vtb_FIFO___024root___ctor_var_reset(Vtb_FIFO___024root* vlSelf);

Vtb_FIFO___024root::Vtb_FIFO___024root(Vtb_FIFO__Syms* symsp, const char* v__name)
    : VerilatedModule{v__name}
    , __VdlySched{*symsp->_vm_contextp__}
    , vlSymsp{symsp}
 {
    // Reset structure values
    Vtb_FIFO___024root___ctor_var_reset(this);
}

void Vtb_FIFO___024root::__Vconfigure(bool first) {
    (void)first;  // Prevent unused variable warning
}

Vtb_FIFO___024root::~Vtb_FIFO___024root() {
}
