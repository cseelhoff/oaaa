#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main() {
    char hostname[1024];
    char baseString[1024] = "Base string: ";
    
    // Get the hostname
    if (gethostname(hostname, sizeof(hostname)) == -1) {
        perror("gethostname");
        return 1;
    }
    
    // Append the hostname to the base string
    strncat(baseString, hostname, sizeof(baseString) - strlen(baseString) - 1);
    
    // Print the result
    printf("%s\n", baseString);
    
    return 0;
}
