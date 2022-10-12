/**
 * @id td-mmio-write
 * @name MMIO Write
 * @kind problem
 * @problem.severity warning
 * @description Find functions that write MMIO
 * @tags MMIO
 *       write
 */

import cpp

from FunctionCall call, Function target, string target_name, Function parent_fn
where
	call.getTarget() = target and 
	target.getName() = target_name and (
		target_name = "TdMmioWrite8" or
		target_name = "TdMmioWrite16" or
		target_name = "TdMmioWrite32" or
		target_name = "TdMmioWrite64"
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, parent_fn.getName()