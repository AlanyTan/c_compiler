#include <stdio.h>
int main()
{char a[ ]="I am a student.",b[20];//定义字符数组
int i;
for(i=0;*(a+i)!='\0';i++)
*(b+i)=*(a+i);
*(b+i)='\0';
printf("string a is:%s\n",a);//输出a数组中全部有效字符
printf("string b is:");
for(i=0;b[i]!='\0';i++)
printf("%c",b[i]);//逐个输出b数组中全部有效字符
printf("\n");
return 0;
}
