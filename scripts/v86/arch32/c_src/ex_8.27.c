#include <stdio.h>
#include <string.h>
int main()
{void sort(char *name[ ],int n);//函数声明
void print(char *name[ ],int n); //函数声明
char *name[ ]={"Follow me","BASIC","Great Wall","FORTRAN","Computer design"};
//定义指针数组,它的元素分别指向5个字符串
int n=5;
sort(name,n); //调用sort函数,对字符串排序
print(name,n);//调用print函数,输出字符串
return 0;
}

void sort(char *name[ ],int n)//定义sort函数
{char *temp;
int i,j,k;
for (i=0;i<n-1;i++) //用选择法排序
{k=i;
for (j=i+1;j<n;j++)
if (strcmp(name[k],name[j])>0) k=j;
if (k!=i)
{temp=name[i]; name[i]=name[k]; name[k]=temp;}
}
}

void print(char *name[ ],int n)//定义print函数
{int i;
for(i=0;i<n;i++)
printf("%s\n",name[i]);//按指针数组元素的顺序输出它们所指向的字符串
}
