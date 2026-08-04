// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_FIFO.h for the primary calling header

#include "Vtb_FIFO__pch.h"
#include "Vtb_FIFO__Syms.h"
#include "Vtb_FIFO___024unit.h"

void Vtb_FIFO___024unit___ctor_var_reset(Vtb_FIFO___024unit* vlSelf);

Vtb_FIFO___024unit::Vtb_FIFO___024unit(Vtb_FIFO__Syms* symsp, const char* v__name)
    : VerilatedModule{v__name}
    , vlSymsp{symsp}
 {
    // Reset structure values
    Vtb_FIFO___024unit___ctor_var_reset(this);
}

void Vtb_FIFO___024unit::__Vconfigure(bool first) {
    (void)first;  // Prevent unused variable warning
}

Vtb_FIFO___024unit::~Vtb_FIFO___024unit() {
}
