/*      ERRORS.C
 *
 * MIDAS Sound System error codes and error message strings
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*/


#include <stdio.h>
#include "lang.h"
#include "errors.h"

char            *errorMsg[] =
{
    "OK",
    "Undefined error",
    "Out of conventional memory",
    "Conventional memory heap corrupted",
    "Invalid conventional memory block",
    "Out of EMS memory",
    "EMS memory heap corrupted",
    "Invalid EMS memory block",
    "Expanded Memory Manager failure",
    "Out of soundcard memory",
    "Soundcard memory heap corrupted",
    "Invalid soundcard memory block",
    "Out of instrument handles",
    "Unable to open file",
    "Unable to read file",
    "Invalid module file",
    "Invalid instrument in module",
    "Invalid pattern data in module",
    "Invalid channel number",
    "Invalid instrument handle",
    "Sound Device channels not open",
    "Sound Device hardware failure",
    "Invalid function arguments",
    "File does not exist",
    "Invalid file handle",
    "Access denied",
    "File exists",
    "Too many open files",
    "Disk full",
    "Unexpected end of file",
    "Invalid path",
    "Unable to write file"
};




#ifdef DEBUG

errRecord   errorList[MAXERRORS];       /* error list */
unsigned    numErrors = 0;              /* number of errors in list */



/****************************************************************************\
*
* Function:     void errAdd(int errorCode, unsigned functID);
*
* Description:  Add an error to error list
*
* Input:        int errorCode           error code
*               unsigned functID        ID for function that caused the error
*
\****************************************************************************/

void CALLING errAdd(int errorCode, unsigned functID)
{
    /* make sure that error list does not overflow */
    if ( numErrors <= MAXERRORS )
    {
        /* store error information to list: */
        errorList[numErrors].errorCode = errorCode;
        errorList[numErrors].functID = functID;

        numErrors++;
    }
}




/****************************************************************************\
*
* Function:     void errPrintList(void);
*
* Description:  Prints the error list to stderr
*
\****************************************************************************/

void CALLING errPrintList(void)
{
    unsigned    i;

    fprintf(stderr, "MIDAS error list:\n");

    for ( i = 0; i < numErrors; i++ )
    {
        fprintf(stderr, "%u: <%i, %u> - %s at %u\n", i,
            errorList[i].errorCode, errorList[i].functID,
            errorMsg[errorList[i].errorCode], errorList[i].functID);
    }
}



#endif
