### How to use SYSCALL system services

Step 1. Load the service number in register a7.  
Step 2. Load argument values, if any, in a0, a1, a2, a3, fa0, ... as specified.  
Step 3. Issue the ECALL instruction.  
Step 4. Retrieve return values, if any, from result registers as specified.  

**Example: display the value stored in $t0 on the console**  

```asm
li  a7, 1          # service 1 is print integer
add a0, t0, zero   # load desired value into argument register a0, using pseudo-op
ecall
```

### Table of Available Services

| Name        | Number | Description                                                      | Inputs                                                                 | Outputs             |
| ----------- | ------ | ---------------------------------------------------------------- | ---------------------------------------------------------------------- | ------------------- |
| PrintInt    | 1      | Prints an integer                                                | a0 = integer to print                                                  | N/A                 |
| ReadInt     | 5      | Reads an int from input console                                  | N/A                                                                    | a0 = the int        |
| Exit        | 10     | Exits the program with code 0                                    | N/A                                                                    | N/A                 |
| ReadChar    | 12     | Reads a character from input console                             | N/A                                                                    | a0 = the character  |
| Sleep       | 32     | Set the current thread to sleep for a time (not precise)         | a0 = time to sleep in milliseconds                                     | N/A                 |
| PrintIntHex | 34     | Prints an integer (in hexdecimal format left-padded with zeroes) | a0 = integer to print                                                  | N/A                 |
| RandInt     | 41     | Get a random integer                                             | N/A                                                                    | a0 = random integer |