//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: Matbi / Austin
//
// Create Date:
// Design Name:
// Project Name:
// Target Devices:
// Tool Versions:
// Description: test data mover BRAM
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
 
#include <stdio.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xtime_l.h"  // To measure of processing time
#include <stdlib.h>	  // To generate rand value
#include <assert.h>

#define WRITE 1
#define CORE_RUN 2
#define READ 3
#define AXI_DATA_BYTE 4
 
#define IDLE 1
#define RUN 1 << 1
#define DONE 1 << 2

#define CTRL_REG 0
#define STATUS_REG 1
#define MEM0_ADDR_REG 2
#define MEM0_DATA_REG 3
#define MEM1_ADDR_REG 4
#define MEM1_DATA_REG 5

#define MEM_DEPTH 4096 

int main() {
	int data;
    int case_num;
    int read_data;
    XTime tStart, tEnd;
	int i;
	int *write_buf;
	write_buf = (int *) malloc(sizeof(int) * MEM_DEPTH);

    while (1) {
    	printf("======= Hello Lab16 Matbi ======\n");
    	printf("plz input run mode\n");
    	printf("1. write to BRAM0 \n");
    	printf("2. DATA Mover BRAM RUN (CTRL) \n");
    	printf("3. read from BRAM1 (REG) \n");

    	scanf("%d",&case_num);

    	if(case_num == WRITE){
    		printf("plz input srand value.\n");
    		scanf("%d",&data);
    		srand(data);
			// (lab13 Memory Test) WRITE to BRAM0
    		Xil_Out32((XPAR_LAB16_MATBI_0_BASEADDR) + (MEM0_ADDR_REG*AXI_DATA_BYTE), (u32)(0x00000000)); // Clear
    		for(i=0; i< MEM_DEPTH ; i++){
    			write_buf[i] = rand();  // problem line
    			Xil_Out32((XPAR_LAB16_MATBI_0_BASEADDR) + (MEM0_DATA_REG*AXI_DATA_BYTE), write_buf[i]); // Clear
    		}
			// (lab13 Memory Test)  READ from BRAM0 for checking
    		Xil_Out32((XPAR_LAB16_MATBI_0_BASEADDR) + (MEM0_ADDR_REG*AXI_DATA_BYTE), (u32)(0x00000000)); // Clear
			for(i=0; i< MEM_DEPTH ; i++){
    			read_data = Xil_In32((XPAR_LAB16_MATBI_0_BASEADDR) + (MEM0_DATA_REG*AXI_DATA_BYTE));
				if(read_data != write_buf[i]){  // Check Read Result
					printf("Matbi!! Mismatch!! plz contact me. idx : %d, Write_data : %d, Read_data : %d\n", i, write_buf[i], read_data);
				}
			}
			printf("Matbi!! Success. Write to BRAM0 \n");
    	} else if (case_num == CORE_RUN){
    		printf("plz input Value 31bit. MSB is the run signal\n");
    		scanf("%d",&data);
			assert( (0 < data) && (data < MEM_DEPTH)); // input range (0 ~ MEM_DEPTH-1)
			Xil_Out32((XPAR_LAB16_MATBI_0_BASEADDR) + (CTRL_REG*AXI_DATA_BYTE), (u32)(0)); // init core ctrl reg
    		// check IDLE
    		do{
    			read_data = Xil_In32((XPAR_LAB16_MATBI_0_BASEADDR) + (STATUS_REG*AXI_DATA_BYTE));
    		} while( (read_data & IDLE) != IDLE);
    		// start core
    		printf("LAB16_MATBI_0 (Data Mover BRAM) Start %d\n",data);
    		Xil_Out32((XPAR_LAB16_MATBI_0_BASEADDR) + (CTRL_REG*AXI_DATA_BYTE), (u32)(data | 0x80000000)); // MSB run
    		XTime_GetTime(&tStart);
    		// wait done
    		do{
    			read_data = Xil_In32((XPAR_LAB16_MATBI_0_BASEADDR) + (STATUS_REG*AXI_DATA_BYTE));
    		} while( (read_data & DONE) != DONE );
    		XTime_GetTime(&tEnd);
    		printf("LAB16_MATBI_0 (Data Mover BRAM) Done\n");
    		printf("Output took %llu clock cycles.\n", 2*(tEnd - tStart));
    		printf("Output took %.2f us.\n",
    		       1.0 * (tEnd - tStart) / (COUNTS_PER_SECOND/1000000));
    	} else if (case_num == READ){
			// (lab13 Memory Test)
    		Xil_Out32((XPAR_LAB16_MATBI_0_BASEADDR) + (MEM1_ADDR_REG*AXI_DATA_BYTE), (u32)(0x00000000)); // Clear
			for(i=0; i< data ; i++){
    			read_data = Xil_In32((XPAR_LAB16_MATBI_0_BASEADDR) + (MEM1_DATA_REG*AXI_DATA_BYTE));
				if(read_data != write_buf[i]){  // Check Read Result
					printf("Matbi!! Mismatch!! plz contact me. idx : %d, Write_data : %d, Read_data : %d\n", i, write_buf[i], read_data);
				}
			}
			printf("Matbi!! Success. Read from BRAM1\n");
    	} else {
    		// no operation, exit
    		//break;
    	}
    }
    return 0;
}

