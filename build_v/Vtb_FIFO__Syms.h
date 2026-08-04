// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VTB_FIFO__SYMS_H_
#define VERILATED_VTB_FIFO__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vtb_FIFO.h"

// INCLUDE MODULE CLASSES
#include "Vtb_FIFO___024root.h"
#include "Vtb_FIFO___024unit.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES)Vtb_FIFO__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vtb_FIFO* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool __Vm_didInit = false;

    // MODULE INSTANCE STATE
    Vtb_FIFO___024root             TOP;

    // SCOPE NAMES
    VerilatedScope __Vscope_tb_FIFO__DUT__fifo_sva_inst;

    // CONSTRUCTORS
    Vtb_FIFO__Syms(VerilatedContext* contextp, const char* namep, Vtb_FIFO* modelp);
    ~Vtb_FIFO__Syms();

    // METHODS
    const char* name() { return TOP.name(); }
};

#endif  // guard
