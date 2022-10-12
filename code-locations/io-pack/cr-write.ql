/**
 * @id cr-write
 * @name CR Write
 * @kind problem
 * @problem.severity warning
 * @description Find functions that write CR
 * @tags CR
 *       write
 */

import cpp

from FunctionCall call, Function target, string target_name, Function parent_fn
where
	call.getTarget() = target and 
	target.getName() = target_name and (
		target_name = "AsmWriteCr0" or
		target_name = "AsmWriteCr2" or
		target_name = "AsmWriteCr3" or
		target_name = "AsmWriteCr4"
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, parent_fn.getName()