/**
* Name: Lujanurbangrowth
* Modelling the Urban Growth of Lujan de Cuyo City, Mendoya, Argentina. 
* Author: s1093342
* Tags: 
*/


model Lujanurbangrowth

global {
	
	//Load study area geojson
	geojson_file study_area_geojson <- geojson_file("../includes/study_area.geojson");
	
	//Load urbanized area geojson
	geojson_file urbanized_2010_geojson <- geojson_file("../includes/urbanized_study_area_2010_reproj.geojson");

	//Load roads geojson
	geojson_file main_roads_geojson <- geojson_file("../includes/main_roads_study_area.geojson", "EPSG:32719");

	//Load Mountain area geojson
	geojson_file mountain_geojson <- geojson_file("../includes/mountain_area_reproj.geojson");

	//Load Lujan center geojson
	geojson_file lujan_center_geojson <- geojson_file("../includes/lujan_center_reproj.geojson", "EPSG:32719");

	//Load Mendoza city center geojson
	geojson_file mendoza_center_geojson <- geojson_file("../includes/mendoza_center_reproj.geojson", "EPSG:32719");
	
	//study area - convert the shapefile into a shape ("shape" is an in-built function for extracting the borders)
	geometry shape <- envelope(study_area_geojson);
	
	//convert the study area shapefile into a polygon
	geometry study_area_polygon <- geometry(study_area_geojson);
	
	//convert the urbanized area shapefile into a polygon
	geometry urbanized_2010 <- geometry(urbanized_2010_geojson);
	
	//Graph of the roads
	graph roads_network;
	
	//declare list of cells within the study area
	list<cells> empty_cells <- cells inside(study_area_polygon);
	
	//declare list of cells within the study area
	list<cells> urban_cells <- cells overlapping(urbanized_2010);
	
	//empty cells that are neighbor of an urban cell
	list<cells> const_cells;
	
	//const_cells ordered by constructability
	list<cells> const_ordered_cells;
	
	//const_cells ordered by constructability
	list<cells> build_cells;
	
	//List of plot colors
	list<rgb> plot_colors <- [ 
		#lightgray, //0  empty
		#darkgray, // 1 built
		#yellow //constructable
	];
	
	//GLOBAL PARAMETERS
	//"Time Parameter" defining how many cells are built. Each step is considered as a month. Here each cell is 4ha
	int built_monthly_cells <- 22;
	//Mountain distance weight
	float mountain_dist_w <- 0.1 min: 0.0 max: 1.0;	//Road network distance weight
	float road_dist_w <- 1.0 min: 0.0 max: 1.0;
	//Mendoza center distance weight
	float mza_dist_w <- 0.35 min: 0.0 max: 1.0;
	//Lujan center distance weight
	float lujan_dist_w <- 0.2 min: 0.0 max: 1.0;
	
    //float step <- 1 #month;
	
	init {
		
		//Creation of the roads using the shapefile of the road
		create roads from: main_roads_geojson;
		//Creation of mendoza center using the shapefile
		create mendoza_center from: mendoza_center_geojson;
		//Creation of lujan center using the shapefile
		create lujan_center from: lujan_center_geojson;
		//Creation of mountaina area using the shapefile
		create mountain_area from: mountain_geojson;
		//Creation of the graph of the road network
		roads_network <- as_edge_graph(roads);
		
		//giving grid_value to cells
		ask cells {
			grid_value <- 0.0;
			color <- plot_colors[0];
			
		}
		
		ask urban_cells {
			grid_value <- 1.0;
			color <- plot_colors[1];
		}
		
		empty_cells <- cells where (each.grid_value = 0.0);
		
		
		//Compute the city distance for each plot
		ask empty_cells {
			do compute_distances;
		}
		//Normalization of the distance
		do normalize_distances;
		
		ask empty_cells {
			do compute_constructability;
		}
		
		//benchmark "bm init";
	}
	
	//Action to normalize the distance
	action normalize_distances {
		//Maximum distance from the road of all the cells
		float max_road_dist <- cells max_of each.road_dist;
		//Maximum distance from mendoza center for all the cells
		float max_mza_dist <- cells max_of each.mza_dist;
		//Maximum distance from lujan center for all the cells
		float max_lujan_dist <- cells max_of each.lujan_dist;
		//Maximum distance from mountain for all the cells
		float max_mountain_dist <- cells max_of each.mountain_dist;
		
		//Normalization of each empty cells according to the maximal value of each attribute
		ask cells {
			road_dist <- 1 - road_dist / max_road_dist;
			mza_dist <- 1 - mza_dist / max_mza_dist;
			lujan_dist <- 1 - lujan_dist / max_lujan_dist;
			mountain_dist <- 1 - mountain_dist / max_mountain_dist;
		}
		
	}
						
	//GLOBAL REFLEX for obtaining a list the constructable cells each step (const_cells)
	reflex global_reflex{	
		
		const_cells <- cells where(each.const_bool = true);
		
		//Sort const_cells by constructability
		const_ordered_cells <- const_cells sort_by (each.constructability);
		//select cells with max constructability
		build_cells <- built_monthly_cells last const_ordered_cells;
		ask build_cells {
			write constructability;
			grid_value <- 1.0;
		}
		//benchmark "global reflex";
	}
	
	//update the list urban_cells, including the new ones
	reflex update_built_cells {
		ask cells {
			urban_cells <- cells where(each.grid_value = 1.0);
			if grid_value = 1.0 {
				color <- plot_colors[1];
			}
		}
		//benchmark "bm update built cells";
	}
	
	//empty the list const cells and return const_bool to false
	reflex update_const_cells {
		ask const_cells {
			const_bool <- false;
		}
		//ask cells {
			//write length(cells);
			const_cells <- [];
			const_ordered_cells <- [];
		//}
		benchmark "bm update const cells";
	}
	
	reflex stop_simulation when: (cycle=42){
		do pause;
		save cells to:"../results/prediction_2017_0_1_0_0.tif" type:geotiff;
	}
		
}


	
	
//SPECIES SECTION

//species representing the roads
species roads {
	aspect default {
		draw shape color: #black;	
	}
}


//species representing Mendoza city center
species mendoza_center {
	aspect center {
		draw circle(400) color: #red;	
	}
}

//species representing Lujan city center
species lujan_center {
	aspect center {
		draw circle(200) color: #red;
}
}

//species representing mountain
species mountain_area {
	aspect mountain {
		draw shape color: #saddlebrown;
}
}

//Study area grid 

grid cells cell_width: 200 cell_height: 200 neighbors:8{
	//Boolean constructability
	bool const_bool <- false;
	//Distance from the roads
	float road_dist <- 0.0;
	//Distance from Mendoza city center
	float mza_dist <- 0.0;
	//Distance from Lujan city center
	float lujan_dist <- 0.0;
	//Distance from the mountains
	float mountain_dist <- 0.0;
	//Constructability is the combined value of all the analzied parametres
	float constructability <- 0.0;
	
	//list neighbours <- (self neighbors_at (1));
	

	
	reflex const {
		if grid_value = 1.0 {
			ask neighbors {
				if grid_value = 0.0 {
					const_bool <- true;
				}
			}
		}
		//benchmark "const";
	}
	//Action to compute all the distances for the cell
	action compute_distances
		{
		roads near_roads <- roads closest_to self;
		road_dist <- self distance_to first (near_roads) using topology(world);
		mza_dist <- self distance_to first(mendoza_center) using topology(world);
		lujan_dist <- self distance_to first(lujan_center) using topology(world);
		mountain_dist <- self distance_to first(mountain_area)using topology (world);
		}
			
	action compute_constructability{
		constructability <- road_dist*road_dist_w + mza_dist*mza_dist_w + lujan_dist*lujan_dist_w + mountain_dist*mountain_dist_w;
	}
	
}

//EXPERIMENT SECTION

experiment UrbanGrowth type: gui {
	
	//user configurable parameters
	parameter 'Mountain Distance Weight' var: mountain_dist_w;
	parameter 'Road Network Distance Weight' var: road_dist_w;
	parameter 'Mendoza Center Distance Weight' var: mza_dist_w;
	parameter 'Lujan Center Distance Weight' var: lujan_dist_w;
	
	output {
		display MyDisplay type:opengl{
			grid cells;
			species roads aspect: default;
			species lujan_center aspect: center;
			species mendoza_center aspect: center;
			species mountain_area aspect: mountain;
		}
	}
	}

