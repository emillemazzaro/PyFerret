"""
Performs a two-sided T-test that two related (paired) samples
come from (normal) distributions with the same mean.
"""
import numpy
import pyferret
import scipy.stats


def ferret_init(id):
    """
    Initialization for the stats_ttest2rel PyEF
    """
    retdict = { "numargs": 2,
                "descript": "Returns two-sided T-test stat. and prob. (and num good pairs) that two " \
                            "related (paired) samples comes from (normal) distribs. with the same mean.",
                "axes": ( pyferret.AXIS_CUSTOM,
                          pyferret.AXIS_DOES_NOT_EXIST,
                          pyferret.AXIS_DOES_NOT_EXIST,
                          pyferret.AXIS_DOES_NOT_EXIST, ),
                "argnames": ( "SAMPLEA", "SAMPLEB", ),
                "argdescripts": ( "First sample data array",
                                  "Second sample data array", ),
                "argtypes": ( pyferret.FLOAT_ARRAY, pyferret.FLOAT_ARRAY, ),
                "influences": ( (False, False, False, False),
                                (False, False, False, False), ),
              }
    return retdict


def ferret_custom_axes(id):
    """
    Define custom axis of the stats_ttest2rel Ferret PyEF
    """
    return ( ( 1, 3, 1, "T,P,N", False ), None, None, None, )


def ferret_compute(id, result, resbdf, inputs, inpbdfs):
    """
    Performs a two-sided T-test that two related (paired) samples come
    from (normal) distributions with the same mean.  The samples are
    given in inputs[0] and inputs[1].  The test statistic value, two-
    tailed probability, and number of good pairs are returned in result.
    Sample pairs with undefined data in either element are removed prior
    to testing.  The samples must either have the same shape or both
    have a single defined non-sigular axis of the same size.
    """
    if inputs[0].shape != inputs[1].shape :
        errmsg = "SAMPLEA and SAMPLEB must either have identical dimensions or "\
            "both have only one defined non-singular axis of the same length"
        lena = 1
        lenb = 1
        for k in xrange(4):
            if inputs[0].shape[k] > 1:
                if lena != 1:
                    raise ValueError(errmsg)
                lena = inputs[0].shape[k]
        for k in xrange(4):
            if inputs[1].shape[k] > 1:
                if lenb != 1:
                    raise ValueError(errmsg)
                lenb = inputs[1].shape[k]
        if lena != lenb:
            raise ValueError(errmsg)
    sampa = inputs[0].reshape(-1)
    sampb = inputs[1].reshape(-1)
    bada = ( numpy.fabs(sampa - inpbdfs[0]) < 1.0E-5 )
    bada = numpy.logical_or(bada, numpy.isnan(sampa))
    badb = ( numpy.fabs(sampb - inpbdfs[1]) < 1.0E-5 )
    badb = numpy.logical_or(badb, numpy.isnan(sampb))
    goodmask = numpy.logical_not(numpy.logical_or(bada, badb))
    # must use double precision arrays for accuracy
    valsa = numpy.array(sampa[goodmask], dtype=numpy.float64)
    numpts = len(valsa)
    if numpts < 2:
        raise ValueError("Not enough defined points in common in SAMPLEA and SAMPLEB")
    valsb = numpy.array(sampb[goodmask], dtype=numpy.float64)
    fitparams = scipy.stats.ttest_rel(valsa, valsb)
    result[:, :, :, :] = resbdf
    # T-test statistic
    result[0, 0, 0, 0] = fitparams[0]
    # probability
    result[1, 0, 0, 0] = fitparams[1]
    # number of good points
    result[2, 0, 0, 0] = numpts


#
# The rest of this is just for testing this module at the command line
#
if __name__ == "__main__":
    # make sure ferret_init and ferret_custom_axes do not have problems
    info = ferret_init(0)
    info = ferret_custom_axes(0)

    # Get a random sample from a normal distribution
    size = 200
    mu = 5.0
    sigma = 2.0
    sampa = scipy.stats.norm(mu, sigma).rvs(size)
    # Create a paired sample with the same mean
    sampb = sampa + scipy.stats.norm(0.0, sigma).rvs(size)
    # Create a paired sample with a different mean
    sampu = sampa + 0.01 * sigma

    # setup for the call to ferret_compute
    inpbdfs = numpy.array([-9999.0, -8888.0], dtype=numpy.float32)
    resbdf = numpy.array([-7777.0], dtype=numpy.float32)
    arraya = numpy.empty((1, size, 1, 1), dtype=numpy.float32, order='F')
    arrayb = numpy.empty((1, 1, size, 1), dtype=numpy.float32, order='F')
    arrayu = numpy.empty((1, 1, size, 1), dtype=numpy.float32, order='F')
    numgood = 0
    for j in xrange(size):
        if (j % 23) == 3:
            arraya[0, j, 0, 0] = inpbdfs[0]
        else:
            arraya[0, j, 0, 0] = sampa[j]
        if (j % 52) == 3:
            arrayb[0, 0, j, 0] = inpbdfs[1]
            arrayu[0, 0, j, 0] = inpbdfs[1]
        else:
            arrayb[0, 0, j, 0] = sampb[j]
            arrayu[0, 0, j, 0] = sampu[j]
        if ((j % 23) != 3) and ((j % 52) != 3):
            numgood += 1
    resultb = -6666.0 * numpy.ones((3, 1, 1, 1), dtype=numpy.float32, order='F')
    resultu = -6666.0 * numpy.ones((3, 1, 1, 1), dtype=numpy.float32, order='F')

    # call ferret_compute with the samples with the same mean and check
    ferret_compute(0, resultb, resbdf, (arraya, arrayb), inpbdfs)
    resultb = resultb.reshape(-1)
    print "same mean result:\n   %s" % str(resultb)
    if (abs(resultb[0]) > 2.0) or \
       (resultb[1] < 0.1) or (resultb[1] > 1.0) or \
       (abs(resultb[2] - numgood) > 1.0E-5):
        raise ValueError("Unexpected result")

    # call ferret_compute with samples with different means and check
    ferret_compute(0, resultu, resbdf, (arraya, arrayu), inpbdfs)
    resultu = resultu.reshape(-1)
    print "diff mean result:\n   %s" % str(resultu)
    if (resultu[0] > -2000.0) or \
       (resultu[1] < 0.00) or (resultu[1] > 0.0001) or \
       (abs(resultb[2] - numgood) > 1.0E-5):
        raise ValueError("Unexpected result")

    # All successful
    print "Success"

