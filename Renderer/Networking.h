//
//  Networking.h
//  MaximallyDirect2D
//
//  Created by Tristan Hume on 2018-07-14.
//  Copyright © 2018 Apple. All rights reserved.
//

#ifndef Networking_h
#define Networking_h

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdio.h>

int createSocket(uint16_t port) {
    int sd = socket(AF_INET,SOCK_DGRAM,0);
    if(sd<0) {
        printf("cannot open socket \n");
        exit(1);
    }

    int broadcast = 1;
    if (setsockopt(sd, SOL_SOCKET, SO_BROADCAST, &broadcast,sizeof broadcast) == -1) {
                    perror("setsockopt (SO_BROADCAST)");
                    exit(1);
    }

    /* bind any port */
    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(port);

    int rc = bind(sd, (struct sockaddr *) &addr, sizeof(addr));
    if(rc<0) {
        printf("cannot bind port\n");
        return 0;
    }

    return sd;
}

void sendData(int sd, const void *buf, size_t len, uint16_t port) {
    struct sockaddr_in remoteAddr;
    remoteAddr.sin_family       = AF_INET;
    remoteAddr.sin_port         = htons(port);
    remoteAddr.sin_addr.s_addr  = INADDR_BROADCAST;

    ssize_t rc = sendto(sd, buf, len, 0, (struct sockaddr *) &remoteAddr, sizeof(remoteAddr));

    if(rc<0) {
        printf("cannot send data\n");
        close(sd);
        exit(1);
    }
}

void listenData(int sd, const void *buf, size_t len) {
    struct sockaddr_in cliAddr;
    int cliLen = sizeof(cliAddr);
    ssize_t n = recvfrom(sd, buf, len, 0, (struct sockaddr *) &cliAddr, &cliLen);
    if(n<0) {
      printf("cannot receive data \n");
      exit(1);
    }
}

#endif /* Networking_h */
