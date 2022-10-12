/**
 * @id td-mmio-read
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
		target_name = "TdMmioRead8" or
		target_name = "TdMmioRead16" or
		target_name = "TdMmioRead32" or
		target_name = "TdMmioRead64"
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, parent_fn.getName()