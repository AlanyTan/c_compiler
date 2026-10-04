#include <stdio.h>
int main()
{
int i,a[10];
for(i=0; i<10;i++)//对从a[0]开始的10个数组元素赋值
a[i]=i;
for(i=9;i>=0; i--)//输出a[9]~a[0]共10个数组元素
printf("%d ",a[i]);
printf("\n");
return 0;
}
