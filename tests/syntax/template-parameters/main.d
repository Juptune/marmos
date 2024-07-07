template A(
    // Type parameters 
    A,
    B : int,
    C = int,
    D : int = byte,

    // Alias parameters
    alias E,
    alias F = 2,
    alias G = int,

    // Value parameters
    string H,
    string I = "abc",

    // Tuple parameter
    Z...
)
{

}