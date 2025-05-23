
#TODO: Create blazed pattern for any angle and using MLSLM structure instead of an inputted phase array


function genblazed!(slm::MLSLM, is_vert::Bool=true, period::Int=32; blaze_start::Int=1, blaze_end::Int=-1)    #Units are pixels
    #Create array of size of SLM    
    width = slm.width
    height = slm.height

    #Create array of size of SLM
    phase_pattern = zeros(Float64, width, height)
    
    if period == 1
        blaze_values = zeros(2)
    else
        blaze_values = LinRange(1, 0, period) #creates a range from 0 to 1 with the period specified
    end

    if is_vert
        pattern_start::Int = (blaze_start)
        
        if blaze_end < 0. || (blaze_end) > height
            blaze_end = height
        else
            pattern_end::Int = (blaze_end)
        end

        for j in pattern_start:pattern_end
            phase_pattern[:, j] .= blaze_values[(j-1)%period+1]
        end
    else
        pattern_start = (blaze_start)

        if blaze_end < 0. || (blaze_end) > width
            blaze_end = width
        else
            pattern_end = (blaze_end)
        end

        for i in pattern_start:pattern_end
            phase_pattern[i, :] .= blaze_values[(i-1)%period+1]
        end
    end
    slm.phase = phase_pattern
end

function genzernike!(slm::MLSLM, radial_order::Int, coefficients::Vector{Float64}, radius::Int, x_center::Int, y_center::Int)
    phase_array = zeros(Float64, slm.width, slm.height)

    x_zernike = LinRange(-1,1, radius*2)
    y_zernike = LinRange(-1,1, radius*2)

    zernike_array = [(x^2 + y^2 > 1 ? 0.0 : (zernike_sum(x, y, radial_order, coefficients))) for x in x_zernike, y in y_zernike]

    reverse!(zernike_array, dims=2) #Reverses along the x axis, so the pattern is drawn correctly on the SLM

    zernike_array = zernike_array .% 2pi #Ranges from -2pi to 2pi

    for j in 1:size(zernike_array)[2]   #Converts negative phase to positive phase
        for i in 1:size(zernike_array)[1] 
            if zernike_array[i, j] < 0
                zernike_array[i, j] = 2pi + zernike_array[i, j]
            end
        end 
    end

    zernike_array = zernike_array ./ 2pi
    #TODO: Handle if radius is too large, only draw area that is on SLM
    if x_center - radius < 1 || x_center + radius - 1 > slm.width || y_center - radius < 1 || y_center + radius - 1 > slm.height

        if x_center-radius < 1
            slm_x_start = 1
            zernike_x_start = 2 + radius-x_center
        else
            slm_x_start = x_center-radius
            zernike_x_start = 1
        end

        if x_center + radius - 1 > slm.width
            slm_x_end = slm.width
            zernike_x_end = radius * 2 + (slm.width - (x_center + radius - 1))
        else
            slm_x_end = x_center + radius - 1
            zernike_x_end = radius*2
        end

        if y_center-radius < 1
            slm_y_start = 1
            zernike_y_start = 2 + radius-y_center
        else
            slm_y_start = y_center-radius
            zernike_y_start = 1
        end

        if y_center + radius - 1 > slm.height
            slm_y_end = slm.height
            zernike_y_end = radius * 2 + (slm.height - (y_center + radius - 1))
        else
            slm_y_end = y_center + radius - 1
            zernike_y_end = radius*2
        end

        println( slm_x_start, " ", slm_x_end)
        println( slm_y_start, " ",slm_y_end)
        println( zernike_x_start, " ", zernike_x_end)
        println( zernike_y_start, " ",zernike_y_end)

        phase_array[slm_x_start:slm_x_end, slm_y_start:slm_y_end] = zernike_array[zernike_x_start:zernike_x_end, zernike_y_start:zernike_y_end]
    else
        phase_array[x_center-radius:x_center+radius-1, y_center-radius:y_center+radius-1] = zernike_array[:,:]
    end
    slm.phase = phase_array
end


#=
This function will use the reccurence reltaions defined in "Efficient and robust recurrence relations for the Zernike circle polynomials and their derivatives in Cartesian coordinates"
It will return an array of values corresponding to the values of a specified number of zernike polynomials.
These are in the order of OSA Zernike polynomials
=#
 function zernike_recurs(x, y, order::Int)
    number_functions::Int = ((order + 1) * (order + 2)) / 2
    zern_polys = Array{Float64,1}(undef, number_functions)
    #Value of x and y lies inside unit disk
    zern_polys[1] = 1
    zern_polys[2] = y
    zern_polys[3] = x

    if order > 1
        #values useful for indexing
        cur_indx = 4            #Index in array
        ps_indx = 2             #Index for for first polynomial of previous radial power (n-1)
        tps_indx = 1            #Index for for first polynomial of second revious radial power (n-2)
        for n = 2:order         #Note: values of n = 0 and n=1 are given, the rest are calculated using the formulas in the paper
            for m = 0:n
                if m == 0
                    zern_polys[cur_indx] = x * zern_polys[ps_indx+(0)] + y * zern_polys[ps_indx+(n-1)]
                elseif m == n
                    zern_polys[cur_indx] = x * zern_polys[ps_indx+(n-1)] - y * zern_polys[ps_indx+(0)]
                elseif m == n / 2
                    zern_polys[cur_indx] = 2 * x * zern_polys[ps_indx+(m)] + 2 * y * zern_polys[ps_indx+(m-1)] - zern_polys[tps_indx+(m-1)]
                elseif m == (n - 1) / 2
                    zern_polys[cur_indx] = y * zern_polys[ps_indx+(n-1-m)] + x * zern_polys[ps_indx+(m-1)] - y * zern_polys[ps_indx+(n-m)] - zern_polys[tps_indx+(m-1)]
                elseif m == ((n - 1) / 2) + 1
                    zern_polys[cur_indx] = x * zern_polys[ps_indx+(m)] + y * zern_polys[ps_indx+(n-1-m)] + x * zern_polys[ps_indx+(m-1)] - zern_polys[tps_indx+(m-1)]
                else
                    zern_polys[cur_indx] = x * zern_polys[ps_indx+(m)] + y * zern_polys[ps_indx+(n-1-m)] + x * zern_polys[ps_indx+(m-1)] - y * zern_polys[ps_indx+(n-m)] - zern_polys[tps_indx+(m-1)]
                end
                cur_indx += 1
            end
            tps_indx += n - 1
            ps_indx += n
        end
    end
    return zern_polys
end

#=
Given an order of zernike polynomials, calculate an array containing their normalization coefficients
=#
function zernike_norm(order)
    #we will use the equation described in the paper to calculate the normalization coefficients
    number_functions::Int = ((order + 1) * (order + 2)) / 2
    norm_coef = Array{Float64,1}(undef, number_functions)
    index = 1
    for n = 0:order
        for m = 0:n
            if n == 2m
                norm_coef[index] = sqrt(n + 1)
            else
                norm_coef[index] = sqrt((2)(n + 1))
            end
            index += 1
        end
    end
    return norm_coef
end

#=
Sums the value of each zernike polynomial multiplied by their respecitve normilaztion coefficient and weight 
=#
function zernike_sum(x, y, order, weights::Vector{Float64})
    return sum(zernike_recurs(x, y, order) .* zernike_norm(order) .* weights)
end
