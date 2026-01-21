#include "xparameters.h"
#include "xgpio.h"
#include "xuartps.h"
#include "xil_printf.h"

XGpio Gpio;

int main() {
    int Status;

    // ------------------------------------------------------------------
    // FIX: Manual Configuration using Base Address
    // Because DEVICE_ID is missing in the new Vitis flow.
    // ------------------------------------------------------------------
    XGpio_Config GpioConfig;
    
    // We populate the config structure manually using definitions from your xparameters.h
    GpioConfig.BaseAddress = XPAR_AXI_GPIO_0_BASEADDR; 
    GpioConfig.InterruptPresent = XPAR_AXI_GPIO_0_INTERRUPT_PRESENT;
    GpioConfig.IsDual = XPAR_AXI_GPIO_0_IS_DUAL;
    //GpioConfig.DeviceId = 0; // We can arbitrarily assign 0

    // Initialize using CfgInitialize (Low-level init)
    Status = XGpio_CfgInitialize(&Gpio, &GpioConfig, GpioConfig.BaseAddress);
    // ------------------------------------------------------------------

    if (Status != XST_SUCCESS) {
        xil_printf("GPIO Init Failed\r\n");
        return XST_FAILURE;
    }

    // Set Channel 1 as All Outputs (0x0)
    XGpio_SetDataDirection(&Gpio, 1, 0x0);

    xil_printf("--- RFID Controller Active ---\r\n");

    u8 RecvChar;
    u32 cmd_index;

    while(1) {
        // Wait for byte from Python
        RecvChar = inbyte(); 

        if (RecvChar >= '0' && RecvChar <= '9') {
            cmd_index = RecvChar - '0';

            // 1. Set Command, Trigger LOW
            XGpio_DiscreteWrite(&Gpio, 1, cmd_index);
            
            // 2. Set Trigger HIGH (Bit 3 = 1) -> Rising Edge
            XGpio_DiscreteWrite(&Gpio, 1, cmd_index | 0x8);
            
            // 3. Set Trigger LOW
            XGpio_DiscreteWrite(&Gpio, 1, cmd_index);

            // Echo back to PC so Python knows it worked
            outbyte(RecvChar);
        }
    }
    return 0;
}