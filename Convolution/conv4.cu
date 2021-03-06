#include<stdio.h>
#include<cuda.h>
#include<math.h>

#define W 1024 // H/W
#define OW (W-4) //output H/W
#define D 8   //depth
#define T 5  //size of kern
#define N 32 //number of kerns
void fillMatrix(char *matrix){

char (*m)[W][D]=(char (*)[W][D])matrix;

for(int i=0;i<W;i++){
	for(int j=0;j<W;j++){
		for(int k=0;k<D;k++){
			m[i][j][k]=(i*j+j*k+i*k+i*2+j*3+k*4)%255;
				}
			}
		}
}


void fillTile(int *tile){

int (*t)[T][T][D]=(int (*)[T][T][D])tile;

for(int i=0;i<N;i++){
	for(int j=0;j<T;j++){
		for(int k=0;k<T;k++){
			for(int l=0;l<D;l++){
			switch((i*j+j*k+k*l+l*i+i*2+j*3+k*4+l*5)%4)				
			{case 0:t[i][j][k][l]=0;break;
			case 1:t[i][j][k][l]=1;break;
			case 2:t[i][j][k][l]=2;break;
			case 3:t[i][j][k][l]=3;break;	

			}
				}
			}
		}
	}

}


void print_matrix_to_file2(float *m)//,unsigned , unsigned T,unsigned G, unsigned D)
 



{
	float (*mat)[T][T][D]=(float (*)[T][T][D])m;	
	const char *fname = "filter";
	FILE *f = fopen(fname, "w");

	

		for(unsigned i=0; i < N; i++) {
		for(unsigned j=0; j < T; j++)
		for(unsigned k=0; k < T; k++) 
		for(unsigned l=0; l < D; l++)
			fprintf(f,"%4f ", mat[i][j][k][l]);
		fprintf(f,"\n");
	}
	fclose(f);
}


void print_matrix_to_file3(float *m)//, unsigned numRows, unsigned numCols) {
	{const char *fname = "result";
	FILE *f = fopen(fname, "w");

	float (*mat)[OW][OW]=(float (*)[OW][OW])m;		

	for(unsigned i=0; i < N; i++) {
		for(unsigned j=0; j < OW; j++)
		for(unsigned k=0;k<OW;k++)
			fprintf(f,"%4f ", mat[i][j][k]);
		fprintf(f,"\n");
	}
	fclose(f);
}

void print_matrix_to_file1(char *m, unsigned numRows, unsigned numCols,unsigned d) {
	const char *fname = "mat";
	FILE *f = fopen(fname, "w");

	char (*mat)[numCols][d]=(char (*)[numCols][d])m;
	for(unsigned i=0; i < numRows; i++) {
		for(unsigned j=0; j < numCols; j++)
			for(unsigned k=0; k < d; k++)
				fprintf(f,"%d ", mat[i][j][k]);
		fprintf(f,"\n");
	}
	fclose(f);
}




__global__ void conv(char *matrix,int *tile,float *output){

int filter=blockIdx.x;
int eX=blockIdx.y;
int eY=threadIdx.x;

char (*m)[W][D]=(char (*)[W][D])matrix;
int (*t)[T][T][D]=(int (*)[T][T][D])tile;
float (*o)[OW][OW]=(float (*)[OW][OW])output;

__shared__ int slice[W][D];

float psum[4];

if(eX<2||eX>W-3) return;

for(int j=0;j<T;j++){
	for(int i=0;i<D;i++){
		slice[eY][i]=m[(eX+j-2)][eY][i];
		
	}
__syncthreads();
	psum[0]=0.0f;
	psum[1]=0.0f;
	psum[2]=0.0f;
	psum[3]=0.0f;
	if(!(eY<2||eY>W-3)){
		

		for(int k=0;k<T;k++){
			for(int l=0;l<D;l++){
				psum[t[filter][j][k][l]]+=slice[eY+k-2][l];				
				
			}
		}
		atomicAdd(&o[filter][(eX-2)][eY-2],psum[0]*-0.2f+psum[1]*-0.1f+psum[2]*0.1f+psum[3]*0.2f);
	}
__syncthreads();

}

}





int main()
{

char *matrix=(char*)malloc(sizeof(char)*W*W*D);
int *tile=(int*)malloc(sizeof(int)*T*T*D*N);
float *output=(float *)malloc(sizeof(float)*(N*OW*OW));


fillMatrix(matrix);
fillTile(tile);


char *Dmatrix;cudaMalloc(&Dmatrix,sizeof(char)*W*W*D);
int *Dtile;cudaMalloc(&Dtile,sizeof(int)*N*T*T*D);
float *Doutput;cudaMalloc(&Doutput,sizeof(float)*(N*OW*OW));

cudaMemcpy(Dmatrix, matrix, sizeof(char)*W*W*D,cudaMemcpyHostToDevice);
cudaMemcpy(Dtile, tile, sizeof(int)*T*T*D*N,cudaMemcpyHostToDevice);

conv<<<dim3(N,W),W>>>(Dmatrix,Dtile,Doutput);

cudaEvent_t start, stop;
cudaEventCreate(&start);
cudaEventCreate(&stop);
float milliseconds = 0;

cudaEventRecord(start);


conv<<<dim3(N,W),W>>>(Dmatrix,Dtile,Doutput);
cudaDeviceSynchronize();


cudaEventRecord(stop);
cudaEventSynchronize(stop);
cudaEventElapsedTime(&milliseconds, start, stop);
printf("%f\n",milliseconds);



cudaMemcpy(output, Doutput, sizeof(float)*(N*OW*OW),cudaMemcpyDeviceToHost);

/*
for(int i=0;i<N;i++){
	for(int j=0;j<T;j++){
		for(int k=0;k<T;k++){
			for(int l=0;l<D;l++){
			printf("%.1f ",tile[i*N+j*T+k*T+l]);//=(i*j-j*k+i*k-k*l)%5;
				}
			}
		}
	}



for(int i=0;i<W;i++){
	for(int j=0;j<W;j++){
		for(int k=0;k<D;k++){
			//for(int l=0;l<N;l++){
			printf("%d ",matrix[i*W+j*W+k]);//=(i*j-j*k+i*k-k*l)%5;
			//	}
			}
		}
	}



printf("\n\n");
for(int i=0;i<N;i++){
	for(int j=0;j<OW;j++){
		for(int k=0;k<OW;k++){
			//for(int l=0;l<N;l++){
			printf("%.1f ",output[i*N+j*OW+k]);//=(i*j-j*k+i*k-k*l)%5;
			//	}
			}
		}
	}
*/

print_matrix_to_file1(matrix,W,W,D);
//print_matrix_to_file2(tile);//,N,T,T,D);
print_matrix_to_file3(output);//,N,OW,OW);
}
