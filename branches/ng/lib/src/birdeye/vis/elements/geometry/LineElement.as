/*  
 * The MIT License
 *
 * Copyright (c) 2008
 * United Nations Office at Geneva
 * Center for Advanced Visual Analytics
 * http://cava.unog.ch
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
 
package birdeye.vis.elements.geometry
{
	import birdeye.vis.VisScene;
	import birdeye.vis.data.DataItemLayout;
	import birdeye.vis.elements.BaseElement;
	import birdeye.vis.guides.renderers.LineRenderer;
	import birdeye.vis.interfaces.INumerableScale;
	import birdeye.vis.scales.*;
	
	import com.degrafa.GraphicPoint;
	import com.degrafa.IGeometry;
	import com.degrafa.core.IGraphicsFill;
	import com.degrafa.geometry.Line;
	import com.degrafa.geometry.splines.BezierSpline;
	import com.degrafa.paint.SolidFill;
	
	import flash.geom.Rectangle;
	import flash.utils.getTimer;

	public class LineElement extends BaseElement
	{
		private const CURVE:String = "curve";
		
		private var _form:String;
		[Inspectable(enumeration="curve,line")]
		public function set form(val:String):void
		{
			_form = val;
			invalidatingDisplay();
		}
		public function get form():String
		{
			return _form;
		}
		
		private var _tension:Number = 2;
		/** Set the tension of the curve form (values from 1 to 5). The higher, the closer to a line form. 
		 * The lower, the more curved the final shape. */
		public function set tension(val:Number):void
		{
			_tension = val;
			invalidatingDisplay();
		}
		
		public function LineElement()
		{
			super();
		}
		
		override protected function commitProperties():void
		{
			super.commitProperties();
			if (! itemRenderer)
				itemRenderer = LineRenderer;
		}

		private var bzSplines:BezierSpline;
		/** @Private 
		 * Called by super.updateDisplayList when the series is ready for layout.*/
		override public function drawElement():void
		{
			if (isReadyForLayout() && _invalidatedElementGraphic)
			{
trace (getTimer(), "drawing line ele");
				super.drawElement();
				removeAllElements();
				if (bzSplines)
					bzSplines.clearGraphicsTargets();
				var xPrev:Number, yPrev:Number;
				var pos1:Number, pos2:Number, zPos:Number;
				var j:Number = 0;
	
				var dataFields:Array = [];
				// prepare data for a standard tooltip message in case the user
				// has not set a dataTipFunction
				dataFields[0] = dim1;
				dataFields[1] = dim2;
				if (dim3) 
					dataFields[2] = dim3;
	
				ggIndex = 0;
	
				var points:Array = [];
				
				for (var cursorIndex:uint = 0; cursorIndex<_dataItems.length; cursorIndex++)
				{
	 				if (graphicsCollection.items && graphicsCollection.items.length>ggIndex)
						gg = graphicsCollection.items[ggIndex];
					else
					{
						gg = new DataItemLayout();
						graphicsCollection.addItem(gg);
					}
					gg.target = this;
					ggIndex++;

					var currentItem:Object = _dataItems[cursorIndex];
					
					if (scale1)
					{
						pos1 = scale1.getPosition(currentItem[dim1]);
					}
					
					if (scale2)
					{
						pos2 = scale2.getPosition(currentItem[dim2]);
						dataFields[1] = dim2;
					}
					
					var scale2RelativeValue:Number = NaN;
	
					if (scale3)
					{
						zPos = scale3.getPosition(currentItem[dim3]);
						scale2RelativeValue = XYZ(scale3).height - zPos;
					}

					if (multiScale)
					{
						pos1 = multiScale.scale1.getPosition(currentItem[dim1]);
						pos2 = INumerableScale(multiScale.scales[
											currentItem[multiScale.dim1]
											]).getPosition(currentItem[dim2]);
					} else if (chart.multiScale) {
						pos1 = chart.multiScale.scale1.getPosition(currentItem[dim1]);
						pos2 = INumerableScale(chart.multiScale.scales[
											currentItem[chart.multiScale.dim1]
											]).getPosition(currentItem[dim2]);
					}
	
					if (chart.coordType == VisScene.POLAR)
					{
	 					var xPos:Number = PolarCoordinateTransform.getX(pos1, pos2, chart.origin);
						var yPos:Number = PolarCoordinateTransform.getY(pos1, pos2, chart.origin);
	 					pos1 = xPos;
						pos2 = yPos; 
						if (j == 0)
						{
							var firstX:Number = pos1, firstY:Number = pos2;
						}
					}
	
					if (colorScale)
					{
						var col:* = colorScale.getPosition(currentItem[colorField]);
						if (col is Number)
							fill = new SolidFill(col);
						else if (col is IGraphicsFill)
							fill = col;
					} 
	
					// scale2RelativeValue is sent instead of zPos, so that the axis pointer is properly
					// positioned in the 'fake' z axis, which corresponds to a real y axis rotated by 90 degrees
    					createTTGG(currentItem, dataFields, pos1, pos2, scale2RelativeValue, 3);
   	 
					if (dim3)
					{
						if (!isNaN(zPos))
						{
							gg = new DataItemLayout();
							gg.target = this;
							graphicsCollection.addItem(gg);
							ttGG.z = gg.z = zPos;
						} else
							zPos = 0;
					}
					
					if (_form == CURVE)
					{
						points.push(new GraphicPoint(pos1,pos2));
						if (isNaN(xPrev) && isNaN(yPrev) && chart.coordType != VisScene.POLAR)
							points.push(new GraphicPoint(pos1,pos2));
					} else if (j++ > 0)
					{
 						var line:Line     = new Line(xPrev,yPrev,pos1,pos2);
						line.fill = fill;
						line.stroke = stroke;
						gg.geometryCollection.addItemAt(line,0);
						line = null;     
					}
	
					if (_showItemRenderer)
					{
		 				var bounds:Rectangle = new Rectangle(pos1 - _rendererSize/2, pos2 - _rendererSize/2, _rendererSize, _rendererSize);
						var shape:IGeometry = new itemRenderer(bounds);
						shape.fill = fill;
						shape.stroke = stroke;
						gg.geometryCollection.addItem(shape);
					}
	
					xPrev = pos1; yPrev = pos2;
					if (dim3)
					{
						gg.z = zPos;
						if (isNaN(zPos))
							zPos = 0;
					}
				}
				
				if (_form == CURVE)
				{
					points.push(new GraphicPoint(pos1+.0000001,pos2));
						
					bzSplines = new BezierSpline(points);
 					bzSplines.tension = _tension;
					bzSplines.stroke = stroke;
					bzSplines.graphicsTarget = [this];
					if (chart.coordType == VisScene.POLAR)
						bzSplines.autoClose = true;
				}
				
				if (chart.coordType == VisScene.POLAR && !isNaN(firstX) && !isNaN(firstY))
				{
						line = new Line(pos1,pos2, firstX, firstY);
						line.fill = fill;
						line.stroke = stroke;
						gg.geometryCollection.addItemAt(line,0);
						line = null;
				}
	
				if (dim3)
					zSort();

				_invalidatedElementGraphic = false;
trace (getTimer(), "drawing line ele");
			}
		}
 	}
}