/**
 * @id pio-write
 * @name PIO Write
 * @kind problem
 * @problem.severity warning
 * @description Find functions that write PIO
 * @tags PIO
 *       write
 */

import cpp

from FunctionCall call, Function target, string target_name, Function parent_fn
where
	call.getTarget() = target and 
	target.getName() = target_name and (
		target_name = "PioWrite8" or
		target_name = "PioWrite16" or
		target_name = "PioWrite32" or
		target_name = "PioWrite64"
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, parent_fn.getName()