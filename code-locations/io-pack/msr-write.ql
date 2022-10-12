/**
 * @id msr-write
 * @name MSR Write
 * @kind problem
 * @problem.severity warning
 * @description Find functions that write MSR
 * @tags MSR
 *       write
 */

import cpp

from FunctionCall call, Function target, string target_name, Function parent_fn
where
	call.getTarget() = target and 
	target.getName() = target_name and (
		target_name = "AsmWriteMsr8" or
		target_name = "AsmWriteMsr16" or
		target_name = "AsmWriteMsr32" or
		target_name = "AsmWriteMsr64"
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, parent_fn.getName()