/**
 * @id msr-read
 * @name MSR Read
 * @kind problem
 * @problem.severity warning
 * @tags MSR
 *       read
 */

import cpp

from FunctionCall call, Function target, string target_name, Function parent_fn
where
	call.getTarget() = target and 
	target.getName() = target_name and (
		target_name = "AsmReadMsr8" or
		target_name = "AsmReadMsr16" or
		target_name = "AsmReadMsr32" or
		target_name = "AsmReadMsr64"
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, parent_fn.getName()