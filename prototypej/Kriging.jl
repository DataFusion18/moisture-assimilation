module Kriging

#
#  The Kriging module provides two types of service:
#
#  * universal kriging with isotropic covariance or correlation
#  * trend surface model kriging
#
#

using Stations
import Stations.nearest_grid_point, Stations.obs_variance, Stations.obs_value

using Storage
import Storage.spush


function universal_kriging(obs, obs_stds, m, m_stds, wrf_data, t)



end


function trend_surface_model_kriging(obs_data, covar)
    """
    Trend surface model kriging, which assumes spatially uncorrelated errors.

    The kriging results in the matrix K, which contains the kriged observations
    and the matrix V, which contains the kriging variance.
    """
    Nobs = length(obs_data)
    dsize = size(covar)[1:2]
    K = zeros(dsize)
    V = zeros(dsize)
    y = zeros((Nobs,1))
    X = zeros((Nobs, size(covar,3)))

    for (obs,i) in zip(obs_data, 1:Nobs)
    	ngp = nearest_grid_point(obs)
        X[i,:] = covar[ngp[1], ngp[2], :]
        y[i] = obs_value(obs)
    end

    #FIXME: we assume that the measurement variance is the same for all stations
    sigma2 = obs_variance(obs_data[1])

    # compute the OLS fit of the covariates to the observations
    spush("kriging_xtx_cond", cond(X' * X))
    XtX_1 = inv(X' * X)
    beta = XtX_1 * X' * y

    # compute kriging field and kriging variance
    for i in 1:size(V,1)
        for j in 1:size(V,2)
            X_ij = squeeze(covar[i,j,:], 1)'
            K[i,j] = (X_ij' * beta)[1,1]
            V[i,j] = sigma2 * (1 + (X_ij' * XtX_1 * X_ij)[1,1])
        end
    end

    return K, V, beta

end


end