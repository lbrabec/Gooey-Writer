//
//  authopenwrapper.h
//  Gooey Writer
//
//  Created by Lukas Brabec on 05.06.2024.
//

#ifndef authopenwrapper_h
#define authopenwrapper_h

int OpenPathForReadWriteUsingAuthopen(const char* path);
int extract_fd(int socket);


#endif /* authopenwrapper_h */
