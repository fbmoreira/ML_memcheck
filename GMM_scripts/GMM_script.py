import math
import numpy as np
from sklearn import mixture
import glob
import sys


#parameter reading
trainpref = sys.argv[1]				#prefix for GMM training inputs
testpref =  sys.argv[2]				#prefix for GMM test inputs
outfile =     sys.argv[3]			#output file in which metrics will be written, currently out of order
featcount =   int(sys.argv[4])			#number of features per observation point e.g. our work uses #reads, #pages read, #writes, #pages written, #instructions, #pages of instructions used
centcount =   int(sys.argv[5])			#number of centroids to use for the gaussian mixture model

#training input initialization
baseobs = np.empty(shape=[0, featcount])	#in
path = trainpref + '*'
for fname in glob.glob(path):			#loop to append all training entries to construct a single dataset for the GMM
	obs1 = np.fromfile(fname, int, -1, ' ')
	baseobs = np.append(baseobs, obs1)	#inefficient method, appending as a list and then converting to numpy might be more efficient, but less readable

msize = centcount * centcount			#Markov chain matrix representation size
baseobs = np.reshape(baseobs, (-1, featcount))

#train GMM
g = mixture.GMM(n_components=centcount, covariance_type='full')	#'full' as an implicit parameter, should we also add the option to the user? number of parameters might be getting large enough that a conf file would be a better option
g.fit(baseobs)

#construction of Markov chain matrix representation
seqarray1 = g.predict(baseobs)
markovchain = np.zeros(msize) 
markovchain = np.reshape(markovchain, (centcount, centcount))
prev = seqarray1[0]
for i in range(1, np.shape(seqarray1)[0] - 1):
  markovchain[prev][seqarray1[i]] = markovchain[prev][seqarray1[i]] + 1
  prev = seqarray1[i]

#divide to get probabilities
for i in range(0, np.shape(markovchain)[0]):
  if np.sum(markovchain[i] > 0):
    markovchain[i] /= np.sum(markovchain[i])

#metrics generation for all inputs
outf = open(outfile, "w")
path = testpref + '*'
for fname in glob.glob(path):
  print(fname)	#just checking if prefix was correct, if this prints nothing, files do not exist with the given prefix
  testfile = np.fromfile(fname, int, -1, ' ')
  fobs = np.reshape(testfile, (-1, 6))
  seqf = g.predict(fobs)
  newmat = np.zeros(msize)
  newmat = np.reshape(newmat, (centcount,centcount))
  unidentified = 0.0	#used for unidentified ratio, calculated earlier for matrix loop efficiency
  identified = 0.0	#used for unidentified ratio
  prev = seqf[0]
  ###create target markov-chain
  for i in range(1, np.shape(seqf)[0] - 1):
    id = seqf[i]
    newmat[prev][id] = newmat[prev][id] + 1
    if (math.isnan(markovchain[prev][id])) or (markovchain[prev][id] == 0):
      unidentified = unidentified + 1
    else:
      identified = identified + 1
    prev = seqf[i]

  for i in range(0, np.shape(newmat)[0]):
	if (np.sum(newmat[i]) != 0):
		newmat[i] /= np.sum(newmat[i])

  #simple matrix total difference calculation
  diffmat = np.zeros(msize) 
  diffmat = np.reshape(diffmat, (centcount,centcount))
  diffmat = markovchain - newmat 
  diffmat = np.absolute(diffmat)
  tdiff = 0
  for i in range(0,centcount):
    tdiff = tdiff + np.sum(diffmat[i])
  
  #sparsity calculation
  notzero = 0.0
  for i in range(0,centcount):
    for k in range(0,centcount): 
      if (newmat[i][k] > 0):
        notzero = notzero + 1
  sparsity = notzero/centcount
  
  #trace calculation
  targetsum = 0.0
  basesum = 0.0
  for k in range(0, centcount):
    targetsum = targetsum + newmat[k][k]
    basesum = basesum + markovchain[k][k]
  trace = math.fabs(targetsum - basesum)
 
  #rank matrix calculation
  rank = math.fabs(np.linalg.matrix_rank(newmat) - np.linalg.matrix_rank(markovchain))

  #unidentified ratio calculation
  unidratio = unidentified / (unidentified + identified)
  strout = "{0},{1},{2},{3},{4},{5}\n".format(fname, tdiff, unidratio, trace, rank, sparsity)
  strout = str(strout)
  print strout 
  outf.write(strout)

#close file
outf.close()
