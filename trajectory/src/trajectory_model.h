/*
 * Date model of trajectory type in Pivotal Greenplum Database
 *
 * Copyright (c) 2015 Pivotal Inc.
 * 
 * Implemented by Kuien Liu <kliu.pivotal.io>
 */

#ifndef _TRAJECTORY_MODEL_H
#define _TRAJECTORY_MODEL_H 1

#include <stdarg.h>
#include <stdio.h>

#include "postgres.h"
#include "fmgr.h"

/*
#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif
*/

Datum trajectory_head_in(PG_FUNCTION_ARGS);
Datum trajectory_head_out(PG_FUNCTION_ARGS);
Datum trajectory_in(PG_FUNCTION_ARGS);
Datum trajectory_out(PG_FUNCTION_ARGS);

#endif
