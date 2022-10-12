/**
 * @id pio-read
 * @name PIO Read
 * @kind problem
 * @problem.severity warning
 * @description Find functions that read PIO
 * @tags PIO
 *       read
 */

import cpp

from FunctionCall call, Function target, string target_name, Function parent_fn
where
	call.getTarget() = target and 
	target.getName() = target_name and (
		target_name = "PioRead8" or
		target_name = "PioRead16" or
		target_name = "PioRead32" or
		target_name = "PioRead64"
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, parent_fn.getName()