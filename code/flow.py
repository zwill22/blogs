import pyflowchart as pyfc

start = pyfc.StartNode("OpenID")
hasID = pyfc.ConditionNode("Has ID?")
idOut = pyfc.InputOutputNode(pyfc.InputOutputNode.OUTPUT, 'ID')
cognito = pyfc.OperationNode("Cognito User Pool")
aws = pyfc.OperationNode('AWS-SDK-CPP')
cond = pyfc.ConditionNode('Valid?')
cInterface = pyfc.SubroutineNode("C Interface")
busTracker = pyfc.EndNode('BusTracker')

start.connect(hasID)
hasID.connect_yes(idOut)
hasID.connect_no(aws)
aws.connect(idOut)
idOut.connect(cond)
aws.connect(cognito)
cond.connect_yes(cInterface)
cond.connect_no(aws)
aws.connect(cognito, direction="right")
cognito.connect(idOut, direction="right")
cInterface.connect(busTracker)

fc = pyfc.Flowchart(start)
print(fc.flowchart())

pyfc.output_html('openid.html', 'OpenID', fc.flowchart())
