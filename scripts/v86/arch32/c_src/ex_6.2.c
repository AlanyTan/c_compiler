#include <stdio.h>
#define LEN 20
int main()
{
int i;
int f[LEN]={1,1};//对最前面两个元素f[0]和f[1]赋初值1
for(i=2;i<LEN;i++)
f[i]=f[i-2]+f[i-1];//先后求出f[2]~f[19]的值
for(i=0;i<LEN;i++)
{
 if(i%5==0) printf("\n"); //控制每输出5个数后换行
 printf("%12d",f[i]);//输出一个数
}
printf("\n");
return 0;
}
