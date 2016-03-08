/*
 * Date model of trajectory type in Pivotal Greenplum Database
 *
 * Copyright (c) 2015 Pivotal Inc.
 *
 * Implemented by Kuien Liu <kliu.pivotal.io>
 */

#include "trajectory_model.h"

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif


/**
** We've NOT implemented these types yet
** so the in/out functions are dummies.
*/
PG_FUNCTION_INFO_V1(trajectory_head_in);
Datum
trajectory_head_in(PG_FUNCTION_ARGS)
{
    ereport(ERROR,(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
                   errmsg("function trajectory_head_in not implemented")));
    PG_RETURN_POINTER(NULL);
}
PG_FUNCTION_INFO_V1(trajectory_head_out);
Datum
trajectory_head_out(PG_FUNCTION_ARGS)
{
	ereport(ERROR,(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
                   errmsg("function trajectory_head_out not implemented")));
    PG_RETURN_POINTER(NULL);
}

/**
** We've NOT implemented these types yet
** so the in/out functions are dummies.
*/
PG_FUNCTION_INFO_V1(trajectory_in);
Datum
trajectory_in(PG_FUNCTION_ARGS)
{
    ereport(ERROR,(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
                   errmsg("function trajectory_in not implemented")));
    PG_RETURN_POINTER(NULL);
}
PG_FUNCTION_INFO_V1(trajectory_out);
Datum
trajectory_out(PG_FUNCTION_ARGS)
{
	ereport(ERROR,(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
                   errmsg("function trajectory_out not implemented")));
    PG_RETURN_POINTER(NULL);
}
