// Copyright (c) 2012 The Chromium OS Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <AppKit/AppKit.h>
#include <CoreFoundation/CoreFoundation.h>
#include <assert.h>
#include <errno.h>
#include <sys/socket.h>
#include <unistd.h>
#include <errno.h>

#define HANDLE_EINTR(x) ({ \
  typeof(x) __eintr_result__; \
  do { \
    __eintr_result__ = x; \
  } while (__eintr_result__ == -1 && errno == EINTR); \
  __eintr_result__;\
})



// Opens a path for read/write using the authopen(1) command-line tool. Returns
// a valid file descriptor or -1 if an error occurs. If -1 is returned, errno
// holds the error value.
int OpenPathForReadWriteUsingAuthopen(const char* path) {
  int sockets[2];  // [parent's end, child's end]
  int result = socketpair(AF_UNIX, SOCK_STREAM, 0, sockets);
  if (result == -1)
    return -1;
  pid_t childPid = fork();
  printf("1");
  if (childPid == -1)
    return -1;
  if (childPid == 0) {  // child
      printf("child");
    HANDLE_EINTR(dup2(sockets[1], STDOUT_FILENO));
    HANDLE_EINTR(close(sockets[0]));
    //HANDLE_EINTR(close(sockets[1]));
    const char authopenPath[] = "/usr/libexec/authopen";
    execl(authopenPath,
          authopenPath,
          "-stdoutpipe",
          "-o",
          [[NSString stringWithFormat:@"%d", O_RDWR] UTF8String],
          path,
          NULL);
      printf("child exit");
    _exit(errno);
  } else {  // parent
      printf("parent");
    HANDLE_EINTR(close(sockets[1]));
    int fd = -1;
    struct msghdr message = { 0 };
    const size_t kDataBufferSize = 1024;
    char dataBuffer[kDataBufferSize];
    struct iovec ioVec[1];
    ioVec[0].iov_base = dataBuffer;
    ioVec[0].iov_len = kDataBufferSize;
    message.msg_iov = ioVec;
    message.msg_iovlen = 1;
    const size_t kCmsgSocketSize = CMSG_SPACE(sizeof(int));
    char cmsgSocket[kCmsgSocketSize];
    message.msg_control = cmsgSocket;
    message.msg_controllen = kCmsgSocketSize;
    ssize_t size = HANDLE_EINTR(recvmsg(sockets[0], &message, 0));
    if (size > 0) {
      struct cmsghdr* cmsgSocketHeader = CMSG_FIRSTHDR(&message);
      // Paranoia.
      if (cmsgSocketHeader &&
          cmsgSocketHeader->cmsg_level == SOL_SOCKET &&
          cmsgSocketHeader->cmsg_type == SCM_RIGHTS)
        fd = *((int *)CMSG_DATA(cmsgSocketHeader));
    }
    int childStat;
    result = HANDLE_EINTR(waitpid(childPid, &childStat, 0));
    HANDLE_EINTR(close(sockets[0]));
    if (result != -1 && WIFEXITED(childStat)) {
      int exitStatus = WEXITSTATUS(childStat);
      if (exitStatus) {
        errno = exitStatus;
        return -1;
      }
    }
    if (fd == -1) {
      errno = ECANCELED;
      return -1;
    }
      printf("%d\n", errno);
    return fd;
  }
}

int extract_fd(int socket){
    printf("socket: %d\n", socket);
    int fd = -1;
    printf("a\n");
    struct msghdr message = { 0 };
    const size_t kDataBufferSize = sizeof(struct cmsghdr) + sizeof(int);
    char dataBuffer[kDataBufferSize];
    struct iovec ioVec[1];
    ioVec[0].iov_base = dataBuffer;
    ioVec[0].iov_len = kDataBufferSize;
    message.msg_iov = ioVec;
    message.msg_iovlen = 1;
    const size_t kCmsgSocketSize = CMSG_SPACE(sizeof(int));
    char cmsgSocket[kCmsgSocketSize];
    message.msg_control = cmsgSocket;
    message.msg_controllen = kCmsgSocketSize;
    ssize_t size = recvmsg(socket, &message, 0);
    printf("b\n");
    if (size > 0) {
        printf("c\n");
      struct cmsghdr* cmsgSocketHeader = CMSG_FIRSTHDR(&message);
      // Paranoia.
        printf("%p\n", cmsgSocketHeader);
        printf("%d\n", cmsgSocketHeader->cmsg_level);
        printf("%d\n", cmsgSocketHeader->cmsg_type);
      if (cmsgSocketHeader &&
          cmsgSocketHeader->cmsg_level == SOL_SOCKET &&
          cmsgSocketHeader->cmsg_type == SCM_RIGHTS){
            printf("d");
            fd = *((int *)CMSG_DATA(cmsgSocketHeader));
      }
          
    }
    close(socket);
    
    printf("e\n");
    if (fd == -1) {
        errno = ECANCELED;
        return -1;
    }
    return fd;
}
