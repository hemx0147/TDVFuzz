/**
 * @id mmio-read
 * @name MMIO Read
 * @kind problem
 * @problem.severity warning
 * @description Find functions that read MMIO
 * @tags MMIO
 *       read
 */

import cpp

from FunctionCall call, Function target, string target_name, Function parent_fn
where
	call.getTarget() = target and 
	target.getName() = target_name and (
		target_name = "MmioRead8" or
		target_name = "MmioRead16" or
		target_name = "MmioRead32" or
		target_name = "MmioRead64"
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, parent_fn.getName()