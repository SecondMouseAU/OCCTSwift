pload ALL
restore model.brep model
explode model e
# blend result model 1.49 model_3 1.49 model_9 1.49 model_11 1.49 model_6 \
# 	1.49 model_13 1.49 model_14 1.49 model_15 1.49 model_16 \
# 	1.49 model_17 1.49 model_18 1.49 model_19 1.49 model_12
blend result model 1.5 model_3 1.5 model_9 1.5 model_11 1.5 model_6 \
	1.5 model_13 1.5 model_14 1.5 model_15 1.5 model_16 \
	1.5 model_17 1.5 model_18 1.5 model_19 1.5 model_12
vdisplay result
vfit
