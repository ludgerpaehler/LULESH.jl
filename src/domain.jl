
function sortRegions(regReps_h, regSorted_h, ::AbstractDomain)
end

function createRegionIndexSets(nr, balance, ::AbstractDomain)
end

# access elements for comms
get_delv_xi(idx::IndexT, dom::AbstractDomain) = dom.d_delv_xi[idx]
get_delv_eta(idx::IndexT, dom::AbstractDomain) = dom.d_delv_eta[idx]
get_delv_zeta(idx::IndexT, dom::AbstractDomain) = dom.d_delv_zeta[idx]

get_x(idx::IndexT, dom::AbstractDomain) = dom.d_x[idx]
get_y(idx::IndexT, dom::AbstractDomain) = dom.d_y[idx]
get_z(idx::IndexT, dom::AbstractDomain) = dom.d_z[idx]

get_xd(idx::IndexT, dom::AbstractDomain) = dom.d_xd[idx]
get_yd(idx::IndexT, dom::AbstractDomain) = dom.d_yd[idx]
get_zd(idx::IndexT, dom::AbstractDomain) = dom.d_zd[idx]

get_fx(idx::IndexT, dom::AbstractDomain) = dom.d_fx[idx]
get_fy(idx::IndexT, dom::AbstractDomain) = dom.d_fy[idx]
get_fz(idx::IndexT, dom::AbstractDomain) = dom.d_fz[idx]

# host access
get_nodalMass(idx::IndexT, dom::AbstractDomain) = dom.h_nodalMass[idx]

colLoc(dom::AbstractDomain) = dom.m_colLoc
rowLoc(dom::AbstractDomain) = dom.m_rowLoc
planeLoc(dom::AbstractDomain) = dom.m_planeLoc
tp(dom::AbstractDomain) = dom.m_tp

function AllocateNodalPersistent!(domain, domNodes)
	resize!(domain.x, domNodes)   # coordinates
	resize!(domain.y, domNodes)
	resize!(domain.z, domNodes)

	resize!(domain.xd, domNodes)  # velocities
	resize!(domain.yd, domNodes)
	resize!(domain.zd, domNodes)

	resize!(domain.xdd, domNodes) # accelerations
	resize!(domain.ydd, domNodes) # accelerations
	resize!(domain.zdd, domNodes) # accelerations

	resize!(domain.fx, domNodes)   # forces
	resize!(domain.fy, domNodes)
	resize!(domain.fz, domNodes)

 	resize!(domain.dfx, domNodes)  # AD derivative of the forces
 	resize!(domain.dfy, domNodes)
 	resize!(domain.dfz, domNodes)

	resize!(domain.nodalMass, domNodes)  # mass
	return nothing
end

function AllocateElemPersistent!(domain, domElems, padded_domElems)
	resize!(domain.matElemlist, domElems) ;  # material indexset */
	resize!(domain.nodelist, 8*padded_domElems) ;   # elemToNode connectivity */

	resize!(domain.lxim, domElems)  # elem connectivity through face g
	resize!(domain.lxip, domElems)
	resize!(domain.letam, domElems)
	resize!(domain.letap, domElems)
	resize!(domain.lzetam, domElems)
	resize!(domain.lzetap, domElems)

	resize!(domain.elemBC, domElems)   # elem face symm/free-surf flag g

	resize!(domain.e, domElems)    # energy g
	resize!(domain.p, domElems)    # pressure g

	resize!(domain.d_e, domElems)  # AD derivative of energy E g

	resize!(domain.q, domElems)    # q g
	resize!(domain.ql, domElems)   # linear term for q g
	resize!(domain.qq, domElems)   # quadratic term for q g
	resize!(domain.v, domElems)      # relative volume g

	resize!(domain.volo, domElems)   # reference volume g
	resize!(domain.delv, domElems)   # m_vnew - m_v g
	resize!(domain.vdov, domElems)   # volume derivative over volume g

	resize!(domain.arealg, domElems)   # elem characteristic length g

	resize!(domain.ss, domElems)       # "sound speed" g

	resize!(domain.elemMass, domElems)   # mass g
	return nothing
end

function InitializeFields!(domain)
	# Basic Field Initialization

	fill!(domain.ss,0.0);
	fill!(domain.e,0.0)
	fill!(domain.p,0.0)
	fill!(domain.q,0.0)
	fill!(domain.v,1.0)

	fill!(domain.d_e,0.0)

	fill!(domain.xd,0.0)
	fill!(domain.yd,0.0)
	fill!(domain.zd,0.0)

	fill!(domain.xdd,0.0)
	fill!(domain.ydd,0.0)
	fill!(domain.zdd,0.0)

	fill!(domain.nodalMass,0.0)
end

function BuildMesh!(domain, nx, edgeNodes, edgeElems, domNodes, padded_domElems, x_h, y_h, z_h, nodelist_h)
	meshEdgeElems = domain.m_tp*nx ;

	resize!(x_h, domNodes)
	resize!(y_h, domNodes)
	resize!(z_h, domNodes)
	# initialize nodal coordinates
	# INDEXING
	nidx::IndexT = 1
	tz = 1.125*(domain.m_planeLoc*nx)/meshEdgeElems
	for plane in 1:edgeNodes
		ty = 1.125*(domain.m_rowLoc*nx)/meshEdgeElems
		for row in 1:edgeNodes
		tx = 1.125*(domain.m_colLoc*nx)/meshEdgeElems
			for col in 1:edgeNodes
				x_h[nidx] = tx
				y_h[nidx] = ty
				z_h[nidx] = tz
				nidx+=1
				# tx += ds ; // may accumulate roundoff...
				tx = 1.125*(domain.m_colLoc*nx+col+1)/meshEdgeElems
			end
		#// ty += ds ;  // may accumulate roundoff...
		ty = 1.125*(domain.m_rowLoc*nx+row+1)/meshEdgeElems
		end
		#// tz += ds ;  // may accumulate roundoff...
		tz = 1.125*(domain.m_planeLoc*nx+plane+1)/meshEdgeElems
	end

	copyto!(domain.x, x_h)
	copyto!(domain.y, y_h)
	copyto!(domain.z, z_h)

	resize!(nodelist_h, padded_domElems*8);

	# embed hexehedral elements in nodal point lattice
	# INDEXING
	zidx::IndexT = 1
	nidx = 1
	for plane in 1:edgeElems
		for row in 1:edgeElems
			for col in 1:edgeElems
				nodelist_h[0*padded_domElems+zidx] = nidx
				nodelist_h[1*padded_domElems+zidx] = nidx                                   + 1
				nodelist_h[2*padded_domElems+zidx] = nidx                       + edgeNodes + 1
				nodelist_h[3*padded_domElems+zidx] = nidx                       + edgeNodes
				nodelist_h[4*padded_domElems+zidx] = nidx + edgeNodes*edgeNodes
				nodelist_h[5*padded_domElems+zidx] = nidx + edgeNodes*edgeNodes             + 1
				nodelist_h[6*padded_domElems+zidx] = nidx + edgeNodes*edgeNodes + edgeNodes + 1
				nodelist_h[7*padded_domElems+zidx] = nidx + edgeNodes*edgeNodes + edgeNodes
				zidx+=1
				nidx+=1
			end
		nidx+=1
		end
    nidx+=edgeNodes
	end
	copyto!(domain.nodelist, nodelist_h)
end

function SetupConnectivityBC!(domain::Domain, edgeElems)
	domElems = domain.numElem;

	lxim_h = Vector{IndexT}(undef, domElems)
	lxip_h = Vector{IndexT}(undef, domElems)
	letam_h = Vector{IndexT}(undef, domElems)
	letap_h = Vector{IndexT}(undef, domElems)
	lzetam_h = Vector{IndexT}(undef, domElems)
	lzetap_h = Vector{IndexT}(undef, domElems)

    # set up elemement connectivity information
    lxim_h[1] = 0 ;
	for i in 2:domElems
       lxim_h[i]   = i-1
       lxip_h[i-1] = i
	end
    lxip_h[domElems-1] = domElems-1

	# INDEXING
	for i in 1:edgeElems
       letam_h[i] = i
       letap_h[domElems-edgeElems+i] = domElems-edgeElems+i
	end

	for i in edgeElems:domElems
       letam_h[i] = i-edgeElems
       letap_h[i-edgeElems+1] = i
    end

	for i in 1:edgeElems*edgeElems
       lzetam_h[i] = i
       lzetap_h[domElems-edgeElems*edgeElems+i] = domElems-edgeElems*edgeElems+i
	end

	for i in edgeElems*edgeElems:domElems
       lzetam_h[i] = i - edgeElems*edgeElems
       lzetap_h[i-edgeElems*edgeElems+1] = i
	end


	# set up boundary condition information
	elemBC_h = Vector{IndexT}(undef, domElems)
	for i in 1:domElems
		elemBC_h[i] = 0   # clear BCs by default
	end

	ghostIdx = [typemin(IndexT) for i in 1:6]::Vector{IndexT} # offsets to ghost locations

	pidx = domElems
	if domain.m_planeMin != 0
		ghostIdx[1] = pidx
		pidx += domain.sizeX*domain.sizeY
	end

	if domain.m_planeMax != 0
		ghostIdx[2] = pidx
		pidx += domain.sizeX*domain.sizeY
	end

	if domain.m_rowMin != 0
		ghostIdx[3] = pidx
		pidx += domain.sizeX*domain.sizeZ
	end

	if domain.m_rowMax != 0
		ghostIdx[4] = pidx
		pidx += domain.sizeX*domain.sizeZ
	end

	if domain.m_colMin != 0
		ghostIdx[5] = pidx
		pidx += domain.sizeY*domain.sizeZ
	end

	if domain.m_colMax != 0
		ghostIdx[6] = pidx
	end

	# symmetry plane or free surface BCs
    for i in 1:edgeElems
		planeInc = (i-1)*edgeElems*edgeElems
		rowInc   = (i-1)*edgeElems
		for j in 1:edgeElems
			if domain.m_planeLoc == 0
				elemBC_h[rowInc+j] |= ZETA_M_SYMM
			else
				elemBC_h[rowInc+j] |= ZETA_M_COMM
				lzetam_h[rowInc+j] = ghostIdx[0] + rowInc + j
			end

			if domain.m_planeLoc == domain.m_tp-1
				elemBC_h[rowInc+j+domElems-edgeElems*edgeElems] |= ZETA_P_FREE
			else
				elemBC_h[rowInc+j+domElems-edgeElems*edgeElems] |= ZETA_P_COMM
				lzetap_h[rowInc+j+domElems-edgeElems*edgeElems] = ghostIdx[1] + rowInc + j
			end

			if domain.m_rowLoc == 0
				elemBC_h[planeInc+j] |= ETA_M_SYMM
			else
				elemBC_h[planeInc+j] |= ETA_M_COMM
				letam_h[planeInc+j] = ghostIdx[2] + rowInc + j
			end

			if domain.m_rowLoc == domain.m_tp-1
				elemBC_h[planeInc+j+edgeElems*edgeElems-edgeElems] |= ETA_P_FREE
			else
				elemBC_h[planeInc+j+edgeElems*edgeElems-edgeElems] |= ETA_P_COMM
				letap_h[planeInc+j+edgeElems*edgeElems-edgeElems] = ghostIdx[3] +  rowInc + j
			end

			if domain.m_colLoc == 0
				elemBC_h[planeInc+j*edgeElems] |= XI_M_SYMM
			else
				elemBC_h[planeInc+j*edgeElems] |= XI_M_COMM
				lxim_h[planeInc+j*edgeElems] = ghostIdx[4] + rowInc + j
			end

			if domain.m_colLoc == domain.m_tp-1
				elemBC_h[planeInc+j*edgeElems+edgeElems-1] |= XI_P_FREE
			else
				elemBC_h[planeInc+j*edgeElems+edgeElems-1] |= XI_P_COMM
				lxip_h[planeInc+j*edgeElems+edgeElems-1] = ghostIdx[5] + rowInc + j
			end
		end
	end

	copyto!(domain.elemBC, elemBC_h)
	copyto!(domain.lxim, lxim_h)
	copyto!(domain.lxip, lxip_h)
	copyto!(domain.letam, letam_h)
	copyto!(domain.letap, letap_h)
	copyto!(domain.lzetam, lzetam_h)
	copyto!(domain.lzetap, lzetap_h)
end

function NewDomain(prob::LuleshProblem)
	VDF = prob.devicetype{prob.floattype}
	VDI = prob.devicetype{IndexT}
	VDInt = prob.devicetype{Int}
	numRanks = getNumRanks(prob.comm)
	colLoc = prob.col
	rowLoc = prob.row
	planeLoc = prob.plane
	nx = prob.nx
	tp = prob.side
	structured = prob.structured
	nr = prob.nr
	balance = prob.balance
	cost = prob.cost
	domain = Domain{prob.floattype}(
		0, nothing,
		VDI(), VDI(),
		VDI(), VDI(), VDI(), VDI(), VDI(), VDI(),
		VDInt(),
		VDF(), VDF(),
		VDF(),
		VDF(), VDF(), VDF(),
		VDF(),
		VDF(), VDF(), VDF(), # volo
		VDF(),
		VDF(),
		VDF(), # elemMass
		VDF(),
		VDF(), VDF(), VDF(),
		VDF(), VDF(), VDF(),
		VDF(), VDF(), VDF(),
		VDF(), VDF(), VDF(),
		VDF(), VDF(), VDF(),
		VDF(), VDF(), VDF(),
		VDF(), VDF(), VDF(),
		VDF(), VDF(), VDF(),
		# FIXIT This is wrong
		VDF(), Vector{prob.floattype}(),
		VDI(), VDI(), VDI(),
		VDInt(), VDInt(), VDI(),
		0.0, 0.0, 0.0, 0.0, 0.0, 0,
		0.0, 0.0, 0.0, 0.0, 0, 0,
		0.0, 0.0,
		0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
		0,0,0,0,0,0,0,0,0,
		0,0,
		0,0,
		0,0,0,
		0,
		0,0,0,0, VDInt(), VDInt(), VDI(), VDI(), VDI()

	)

	domain.max_streams = 32
	# domain->streams.resize(domain->max_streams);
	# TODO: CUDA stream stuff goes here
	domain.streams = nothing

# #   for (Int_t i=0;i<domain->max_streams;i++)
# #     cudaStreamCreate(&(domain->streams[i]));

# #   cudaEventCreateWithFlags(&domain->time_constraint_computed,cudaEventDisableTiming);

#   Index_t domElems;
#   Index_t domNodes;
#   Index_t padded_domElems;

    nodelist_h = Vector{IndexT}()
    x_h = Vector{prob.floattype}()
    y_h = Vector{prob.floattype}()
    z_h = Vector{prob.floattype}()

	if structured

		domain.m_tp       = tp
		# domain.m_numRanks = numRanks

		domain.m_colLoc   =   colLoc
		domain.m_rowLoc   =   rowLoc
		domain.m_planeLoc = planeLoc

		edgeElems = nx
		edgeNodes = edgeElems+1

		domain.sizeX = edgeElems
		domain.sizeY = edgeElems
		domain.sizeZ = edgeElems

		domain.numElem = domain.sizeX*domain.sizeY*domain.sizeZ ;
		domain.padded_numElem = PAD(domain.numElem,32);

		domain.numNode = (domain.sizeX+1)*(domain.sizeY+1)*(domain.sizeZ+1)
		domain.padded_numNode = PAD(domain.numNode,32);

		domElems = domain.numElem
		domNodes = domain.numNode
		padded_domElems = domain.padded_numElem

		# Build domain object here. Not nice.


		AllocateElemPersistent!(domain, domElems, padded_domElems);
		AllocateNodalPersistent!(domain, domNodes);

	#     domain->SetupCommBuffers(edgeNodes);

		InitializeFields!(domain)

		BuildMesh!(domain, nx, edgeNodes, edgeElems, domNodes, padded_domElems, x_h, y_h, z_h, nodelist_h)

		domain.numSymmX = domain.numSymmY = domain.numSymmZ = 0

		if domain.m_colLoc == 0
			domain.numSymmX = (edgeElems+1)*(edgeElems+1)
		end
		if domain.m_rowLoc == 0
			domain.numSymmY = (edgeElems+1)*(edgeElems+1)
		end
		if domain.m_planeLoc == 0
			domain.numSymmZ = (edgeElems+1)*(edgeElems+1)
		end
		resize!(domain.symmX, edgeNodes*edgeNodes)
		resize!(domain.symmY, edgeNodes*edgeNodes)
		resize!(domain.symmZ, edgeNodes*edgeNodes)

		# Set up symmetry nodesets

		symmX_h = convert(Vector, domain.symmX)
		symmY_h = convert(Vector, domain.symmY)
		symmZ_h = convert(Vector, domain.symmZ)

		nidx = 1
		# INDEXING
		for i in 1:edgeNodes
			planeInc = (i-1)*edgeNodes*edgeNodes
			rowInc   = (i-1)*edgeNodes
			for j in 1:edgeNodes
				if domain.m_planeLoc == 0
					symmZ_h[nidx] = rowInc   + j
				end
				if domain.m_rowLoc == 0
					symmY_h[nidx] = planeInc + j
				end
				if domain.m_colLoc == 0
					symmX_h[nidx] = planeInc + j*edgeNodes
				end
				nidx+=1
			end
		end
		if domain.m_planeLoc == 0
			domain.symmZ = symmZ_h
		end
		if domain.m_rowLoc == 0
			domain.symmY = symmY_h
		end
		if domain.m_colLoc == 0
			domain.symmX = symmX_h
		end

		# SetupConnectivityBC!(domain, edgeElems);
	else
		error("Reading unstructured mesh is currently missing in the Julia version of LULESH.")
	end

#   /* set up node-centered indexing of elements */
#   Vector_h<Index_t> nodeElemCount_h(domNodes);

#   for (Index_t i=0; i<domNodes; ++i) {
#      nodeElemCount_h[i] = 0 ;
#   }

#   for (Index_t i=0; i<domElems; ++i) {
#      for (Index_t j=0; j < 8; ++j) {
#         ++(nodeElemCount_h[nodelist_h[j*padded_domElems+i]]);
#      }
#   }

#   Vector_h<Index_t> nodeElemStart_h(domNodes);

#   nodeElemStart_h[0] = 0;
#   for (Index_t i=1; i < domNodes; ++i) {
#      nodeElemStart_h[i] =
#         nodeElemStart_h[i-1] + nodeElemCount_h[i-1] ;
#   }

#   Vector_h<Index_t> nodeElemCornerList_h(nodeElemStart_h[domNodes-1] +
#                  nodeElemCount_h[domNodes-1] );

#   for (Index_t i=0; i < domNodes; ++i) {
#      nodeElemCount_h[i] = 0;
#   }

#   for (Index_t j=0; j < 8; ++j) {
#     for (Index_t i=0; i < domElems; ++i) {
#         Index_t m = nodelist_h[padded_domElems*j+i];
#         Index_t k = padded_domElems*j + i ;
#         Index_t offset = nodeElemStart_h[m] +
#                          nodeElemCount_h[m] ;
#         nodeElemCornerList_h[offset] = k;
#         ++(nodeElemCount_h[m]) ;
#      }
#   }

#   Index_t clSize = nodeElemStart_h[domNodes-1] +
#                    nodeElemCount_h[domNodes-1] ;
#   for (Index_t i=0; i < clSize; ++i) {
#      Index_t clv = nodeElemCornerList_h[i] ;
#      if ((clv < 0) || (clv > padded_domElems*8)) {
#           fprintf(stderr,
#    "AllocateNodeElemIndexes(): nodeElemCornerList entry out of range!\n");
#           exit(1);
#      }
#   }

#   domain->nodeElemStart = nodeElemStart_h;
#   domain->nodeElemCount = nodeElemCount_h;
#   domain->nodeElemCornerList = nodeElemCornerList_h;

#   /* Create a material IndexSet (entire domain same material for now) */
#   Vector_h<Index_t> matElemlist_h(domElems);
#   for (Index_t i=0; i<domElems; ++i) {
#      matElemlist_h[i] = i ;
#   }
#   domain->matElemlist = matElemlist_h;

#   cudaMallocHost(&domain->dtcourant_h,sizeof(Real_t),0);
#   cudaMallocHost(&domain->dthydro_h,sizeof(Real_t),0);
#   cudaMallocHost(&domain->bad_vol_h,sizeof(Index_t),0);
#   cudaMallocHost(&domain->bad_q_h,sizeof(Index_t),0);

#   *(domain->bad_vol_h)=-1;
#   *(domain->bad_q_h)=-1;
#   *(domain->dthydro_h)=1e20;
#   *(domain->dtcourant_h)=1e20;

#   /* initialize material parameters */
#   domain->time_h      = Real_t(0.) ;
#   domain->dtfixed = Real_t(-1.0e-6) ;
#   domain->deltatimemultlb = Real_t(1.1) ;
#   domain->deltatimemultub = Real_t(1.2) ;
#   domain->stoptime  = Real_t(1.0e-2) ;
#   domain->dtmax     = Real_t(1.0e-2) ;
#   domain->cycle   = 0 ;

#   domain->e_cut = Real_t(1.0e-7) ;
#   domain->p_cut = Real_t(1.0e-7) ;
#   domain->q_cut = Real_t(1.0e-7) ;
#   domain->u_cut = Real_t(1.0e-7) ;
#   domain->v_cut = Real_t(1.0e-10) ;

#   domain->hgcoef      = Real_t(3.0) ;
#   domain->ss4o3       = Real_t(4.0)/Real_t(3.0) ;

#   domain->qstop              =  Real_t(1.0e+12) ;
#   domain->monoq_max_slope    =  Real_t(1.0) ;
#   domain->monoq_limiter_mult =  Real_t(2.0) ;
#   domain->qlc_monoq          = Real_t(0.5) ;
#   domain->qqc_monoq          = Real_t(2.0)/Real_t(3.0) ;
#   domain->qqc                = Real_t(2.0) ;

#   domain->pmin =  Real_t(0.) ;
#   domain->emin = Real_t(-1.0e+15) ;

#   domain->dvovmax =  Real_t(0.1) ;

#   domain->eosvmax =  Real_t(1.0e+9) ;
#   domain->eosvmin =  Real_t(1.0e-9) ;

#   domain->refdens =  Real_t(1.0) ;

#   /* initialize field data */
#   Vector_h<Real_t> nodalMass_h(domNodes);
#   Vector_h<Real_t> volo_h(domElems);
#   Vector_h<Real_t> elemMass_h(domElems);

#   for (Index_t i=0; i<domElems; ++i) {
#      Real_t x_local[8], y_local[8], z_local[8] ;
#      for( Index_t lnode=0 ; lnode<8 ; ++lnode )
#      {
#        Index_t gnode = nodelist_h[lnode*padded_domElems+i];
#        x_local[lnode] = x_h[gnode];
#        y_local[lnode] = y_h[gnode];
#        z_local[lnode] = z_h[gnode];
#      }

#      // volume calculations
#      Real_t volume = CalcElemVolume(x_local, y_local, z_local );
#      volo_h[i] = volume ;
#      elemMass_h[i] = volume ;
#      for (Index_t j=0; j<8; ++j) {
#         Index_t gnode = nodelist_h[j*padded_domElems+i];
#         nodalMass_h[gnode] += volume / Real_t(8.0) ;
#      }
#   }

#   domain->nodalMass = nodalMass_h;
#   domain->volo = volo_h;
#   domain->elemMass= elemMass_h;

#    /* deposit energy */
#    domain->octantCorner = 0;
#   // deposit initial energy
#   // An energy of 3.948746e+7 is correct for a problem with
#   // 45 zones along a side - we need to scale it
#   const Real_t ebase = 3.948746e+7;
#   Real_t scale = (nx*domain->m_tp)/45.0;
#   Real_t einit = ebase*scale*scale*scale;
#   //Real_t einit = ebase;
#   if (domain->m_rowLoc + domain->m_colLoc + domain->m_planeLoc == 0) {
#      // Dump into the first zone (which we know is in the corner)
#      // of the domain that sits at the origin
#        domain->e[0] = einit;
#   }

#   //set initial deltatime base on analytic CFL calculation
#   domain->deltatime_h = (.5*cbrt(domain->volo[0]))/sqrt(2*einit);

#   domain->cost = cost;
#   domain->regNumList.resize(domain->numElem) ;  // material indexset
#   domain->regElemlist.resize(domain->numElem) ;  // material indexset
#   domain->regCSR.resize(nr);
#   domain->regReps.resize(nr);
#   domain->regSorted.resize(nr);

#   // Setup region index sets. For now, these are constant sized
#   // throughout the run, but could be changed every cycle to
#   // simulate effects of ALE on the lagrange solver

#   domain->CreateRegionIndexSets(nr, balance);

	# return domain ;
end