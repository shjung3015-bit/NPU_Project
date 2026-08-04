// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vtb_FIFO__pch.h"

//============================================================
// Constructors

Vtb_FIFO::Vtb_FIFO(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vtb_FIFO__Syms(contextp(), _vcname__, this)}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vtb_FIFO::Vtb_FIFO(const char* _vcname__)
    : Vtb_FIFO(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vtb_FIFO::~Vtb_FIFO() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vtb_FIFO___024root___eval_debug_assertions(Vtb_FIFO___024root* vlSelf);
#endif  // VL_DEBUG
void Vtb_FIFO___024root___eval_static(Vtb_FIFO___024root* vlSelf);
void Vtb_FIFO___024root___eval_initial(Vtb_FIFO___024root* vlSelf);
void Vtb_FIFO___024root___eval_settle(Vtb_FIFO___024root* vlSelf);
void Vtb_FIFO___024root___eval(Vtb_FIFO___024root* vlSelf);

void Vtb_FIFO::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vtb_FIFO::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vtb_FIFO___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        vlSymsp->__Vm_didInit = true;
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vtb_FIFO___024root___eval_static(&(vlSymsp->TOP));
        Vtb_FIFO___024root___eval_initial(&(vlSymsp->TOP));
        Vtb_FIFO___024root___eval_settle(&(vlSymsp->TOP));
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vtb_FIFO___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vtb_FIFO::eventsPending() { return !vlSymsp->TOP.__VdlySched.empty(); }

uint64_t Vtb_FIFO::nextTimeSlot() { return vlSymsp->TOP.__VdlySched.nextTimeSlot(); }

//============================================================
// Utilities

const char* Vtb_FIFO::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vtb_FIFO___024root___eval_final(Vtb_FIFO___024root* vlSelf);

VL_ATTR_COLD void Vtb_FIFO::final() {
    Vtb_FIFO___024root___eval_final(&(vlSymsp->TOP));
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vtb_FIFO::hierName() const { return vlSymsp->name(); }
const char* Vtb_FIFO::modelName() const { return "Vtb_FIFO"; }
unsigned Vtb_FIFO::threads() const { return 1; }
void Vtb_FIFO::prepareClone() const { contextp()->prepareClone(); }
void Vtb_FIFO::atClone() const {
    contextp()->threadPoolpOnClone();
}
