"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

@doc raw"""
	write_co2_load_emission_rate_cap_price_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting carbon price of load emission rate carbon cap.

"""
function write_co2_load_emission_rate_cap_price_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    # L = inputs["L"]     # Number of transmission lines
    # W = inputs["REP_PERIOD"]     # Number of subperiods
    SEG = inputs["SEG"] # Number of load curtailment segments

    tempCO2Price = zeros(Z, inputs["NCO2LoadRateCap"])
    for cap = 1:inputs["NCO2LoadRateCap"]
        for z in findall(x -> x == 1, inputs["dfCO2LoadRateCapZones"][:, cap])
            if setup["ParameterScale"] == 1
                tempCO2Price[z, cap] = (-1) * dual.(EP[:cCO2Emissions_loadrate])[cap] * ModelScalingFactor
            else
                tempCO2Price[z, cap] = (-1) * dual.(EP[:cCO2Emissions_loadrate])[cap]
            end
        end
    end
    dfCO2LoadRatePrice = hcat(DataFrame(Zone = 1:Z), DataFrame(tempCO2Price, :auto))
    auxNew_Names = [Symbol("Zone"); [Symbol("CO2_LoadRate_Price_$cap") for cap = 1:inputs["NCO2LoadRateCap"]]]
    rename!(dfCO2LoadRatePrice, auxNew_Names)
    CSV.write(string(path, sep, "CO2Price_loadrate.csv"), dfCO2LoadRatePrice, writeheader = false)


    temp_NSE = sum(value.(EP[:vNSE])[s, :, :] for s = 1:SEG) # nse is [S x T x Z], thus temp_NSE is [T x Z]
    CO2CapEligibleLoad = DataFrame(CO2CapEligibleLoad_MWh = zeros(Z))
    Storageloss = DataFrame(Storageloss_MWh = zeros(Z))
    for z = 1:Z
        CO2CapEligibleLoad[z, :CO2CapEligibleLoad_MWh] = sum(inputs["omega"] .* (inputs["pD"][:, z] - temp_NSE[:, z]))
        Storageloss[z, :Storageloss_MWh] = setup["StorageLosses"] * value.(EP[:eELOSSByZone])[z]
    end


    dfCO2LoadRateCapRev = DataFrame(Zone = 1:Z, AnnualSum = zeros(Z))
    for cap = 1:inputs["NCO2LoadRateCap"]
        temp_CO2LoadRateCapRev = DataFrame(A = zeros(Z), B = zeros(Z))
        if setup["ParameterScale"] == 1
            temp_CO2LoadRateCapRev.A = (-1) * (dual.(EP[:cCO2Emissions_loadrate])[cap]) * (inputs["dfCO2LoadRateCapZones"][:, cap]) .* (inputs["dfMaxCO2LoadRate"][:, cap]) .* CO2CapEligibleLoad[!, :CO2CapEligibleLoad_MWh] * ModelScalingFactor * ModelScalingFactor
            temp_CO2LoadRateCapRev.B = (-1) * (dual.(EP[:cCO2Emissions_loadrate])[cap]) * (inputs["dfCO2LoadRateCapZones"][:, cap]) .* (inputs["dfMaxCO2LoadRate"][:, cap]) .* Storageloss[!, :Storageloss_MWh] * ModelScalingFactor * ModelScalingFactor
        else
            temp_CO2LoadRateCapRev.A = (-1) * (dual.(EP[:cCO2Emissions_loadrate])[cap]) * (inputs["dfCO2LoadRateCapZones"][:, cap]) .* (inputs["dfMaxCO2LoadRate"][:, cap]) .* CO2CapEligibleLoad[!, :CO2CapEligibleLoad_MWh]
            temp_CO2LoadRateCapRev.B = (-1) * (dual.(EP[:cCO2Emissions_loadrate])[cap]) * (inputs["dfCO2LoadRateCapZones"][:, cap]) .* (inputs["dfMaxCO2LoadRate"][:, cap]) .* Storageloss[!, :Storageloss_MWh]
        end
        dfCO2LoadRateCapRev = hcat(dfCO2LoadRateCapRev, temp_CO2LoadRateCapRev)
        rename!(dfCO2LoadRateCapRev, Dict(:A => Symbol("CO2_LoadRateCap_Revenue_$cap"), :B => Symbol("CO2_LoadRateCap_Revenue_StorageLoss_$cap")))
    end
    dfCO2LoadRateCapRev.AnnualSum = sum(eachcol(dfCO2LoadRateCapRev[:, 3:(2*inputs["NCO2LoadRateCap"]+2)]))
    CSV.write(string(path, sep, "CO2Revenue_loadrate.csv"), dfCO2LoadRateCapRev, writeheader = false)

    dfCO2LoadRateCapCost = DataFrame(Resource = inputs["RESOURCES"], AnnualSum = zeros(G))
    for cap = 1:inputs["NCO2LoadRateCap"]
        temp_CO2LoadRateCapCost = DataFrame(A = zeros(G))
        for g = 1:G
            temp_z = dfGen[g, :Zone]
            if setup["ParameterScale"] == 1
                temp_CO2LoadRateCapCost[g, :A] = (-1) * (dual.(EP[:cCO2Emissions_loadrate])[cap]) * sum(inputs["omega"] .* (value.(EP[:eEmissionsByPlant])[g, :])) * (inputs["dfCO2LoadRateCapZones"][temp_z, cap]) * ModelScalingFactor * ModelScalingFactor
            else
                temp_CO2LoadRateCapCost[g, :A] = (-1) * (dual.(EP[:cCO2Emissions_loadrate])[cap]) * sum(inputs["omega"] .* (value.(EP[:eEmissionsByPlant])[g, :])) * (inputs["dfCO2LoadRateCapZones"][temp_z, cap])
            end
        end
        dfCO2LoadRateCapCost = hcat(dfCO2LoadRateCapCost, temp_CO2LoadRateCapCost)
        rename!(dfCO2LoadRateCapCost, Dict(:A => Symbol("CO2_LoadRateCap_Cost_$cap")))
    end
    dfCO2LoadRateCapCost.AnnualSum = sum(eachcol(dfCO2LoadRateCapCost[:, 3:inputs["NCO2LoadRateCap"]+2]))
    CSV.write(string(path, sep, "CO2Cost_loadrate.csv"), dfCO2LoadRateCapCost, writeheader = false)

    return dfCO2LoadRatePrice, dfCO2LoadRateCapRev, dfCO2LoadRateCapCost
end