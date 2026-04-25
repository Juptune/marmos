module test;

alias a = T;
alias b = Eponymous!();
alias c = EponymousWithParam!int;
alias e = WithParam!bool.field;

template T(){}

template Eponymous()
{
    int Eponymous = 0;
}

template EponymousWithParam(A)
{
    A EponymousWithParam = 0;
}

template WithParam(A)
{
    A field;
}