function configure_highs(solver_settings_path::String)

	solver_settings = YAML.load(open(solver_settings_path))
    # https://github.com/jump-dev/HiGHS.jl/blob/master/README.md
	# Optional solver parameters ############################################
	Mypresolve = "on"
        if(haskey(solver_settings, "presolve")) Mypresolve = solver_settings["presolve"] end
    Myparallel = "on"
        if(haskey(solver_settings, "parallel")) Myparallel = solver_settings["parallel"] end
	Mythreads = 1
		if(haskey(solver_settings, "threads")) Mythreads = solver_settings["threads"] end
	########################################################################

	OPTIMIZER = optimizer_with_attributes(HiGHS.Optimizer,
		"presolve" => Mypresolve,
		"parallel" => Myparallel,
		"threads" => Mythreads
	)

	return OPTIMIZER
end