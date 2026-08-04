// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table implementation internals

#include "Vtb_FIFO__pch.h"
#include "Vtb_FIFO.h"
#include "Vtb_FIFO___024root.h"
#include "Vtb_FIFO___024unit.h"

// FUNCTIONS
Vtb_FIFO__Syms::~Vtb_FIFO__Syms()
{
}

Vtb_FIFO__Syms::Vtb_FIFO__Syms(VerilatedContext* contextp, const char* namep, Vtb_FIFO* modelp)
    : VerilatedSyms{contextp}
    // Setup internal state of the Syms class
    , __Vm_modelp{modelp}
    // Setup module instances
    , TOP{this, namep}
{
        // Check resources
        Verilated::stackCheck(18);
    // Configure time unit / time precision
    _vm_contextp__->timeunit(-9);
    _vm_contextp__->timeprecision(-12);
    // Setup each module's pointers to their submodules
    // Setup each module's pointer back to symbol table (for public functions)
    TOP.__Vconfigure(true);
    // Setup scopes
    __Vscope_tb_FIFO__DUT__fifo_sva_inst.configure(this, name(), "tb_FIFO.DUT.fifo_sva_inst", "fifo_sva_inst", "<null>", -9, VerilatedScope::SCOPE_OTHER);
}
