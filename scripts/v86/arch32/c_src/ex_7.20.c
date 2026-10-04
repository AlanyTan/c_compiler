#include <stdio.h>
void enter_string(char str[])
{
    gets(str);
}
void delete_string(char str[],char ch)
{
    int i,j;
    for(i=j=0;str[i]!='\0';i++)
        if(str[i]!=ch)
            str[j++]=str[i];
    str[j]='\0';
}
void print_string(char str[])
{
    printf("%s\n",str);
}
int main()
{
    char c,str[80];
    enter_string(str);
    scanf("%c",&c);
    delete_string(str,c);
    print_string(str);
    return 0;
}
