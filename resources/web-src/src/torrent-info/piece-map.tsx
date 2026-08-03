import React, { useEffect, useRef } from 'react';
import { useDebounce } from 'use-debounce/lib';
import useResizeObserver from 'use-resize-observer';
import { Theme } from '../Services/settings';

interface IPieceMapProps {
  pieces: string;
  theme: Theme;
}

const PieceSize = 8;
const Margin = 1;
const FullSize = PieceSize + Margin;

const drawLegend = (context: CanvasRenderingContext2D, legendHeight: number, theme: Theme) => {
  const y = context.canvas.height - legendHeight / 2;
  context.font = '12px sans-serif';
  const pieceSize = PieceSize * 1.3;

  const drawLegendItem = (fillStyle: string, x: number, text: string) => {
    context.fillStyle = fillStyle;
    context.fillRect(x, y, pieceSize, pieceSize);

    context.fillStyle = theme === 'dark' ? '#e6edf3' : '#1b1c1d';
    context.fillText(text, x + PieceSize * 2, y + pieceSize);
  };

  drawLegendItem('#4CAF50', 0, '- Done');
  drawLegendItem('#ECEFF1', 70, '- Queued');
  drawLegendItem('#F0B8B8', 170, '- Not selected');
};

const draw = (parentDiv: HTMLDivElement, context: CanvasRenderingContext2D, pieces: string, theme: Theme) => {
  const parentWidth = parentDiv.clientWidth;
  const piecesPerLine = Math.floor(parentWidth / FullSize);
  const height = Math.ceil(pieces.length / piecesPerLine) * FullSize;
  const legendHeight = 30;

  const { canvas } = context;
  canvas.width = parentWidth;
  canvas.height = height + legendHeight;

  for (let i = 0; i < pieces.length; i += 1) {
    let pieceColor;

    switch (pieces[i]) {
      case '+':
        pieceColor = '#4CAF50';
        break;
      case '-':
        pieceColor = '#F0B8B8';
        break;
      default:
        pieceColor = theme === 'dark' ? '#4b5563' : '#ECEFF1';
        break;
    }

    context.fillStyle = pieceColor;
    context.fillRect(FullSize * (i % piecesPerLine), Math.floor(i / piecesPerLine) * FullSize, PieceSize, PieceSize);
  }

  drawLegend(context, legendHeight, theme);
};

const PieceMap = ({ pieces, theme }: IPieceMapProps): JSX.Element => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const parentDivRef = useRef<HTMLDivElement>(null);
  const { width } = useResizeObserver<HTMLDivElement>({ ref: parentDivRef });
  const [debouncedWidth] = useDebounce(width, 100);

  useEffect(() => {
    if (!debouncedWidth) return;

    const canvas = canvasRef.current;
    if (!canvas) return;

    const context = canvas.getContext('2d');
    if (!context) return;

    const parentDiv = parentDivRef.current;
    if (!parentDiv) return;

    draw(parentDiv, context, pieces, theme);
  }, [pieces, debouncedWidth, theme]);

  return (
    <div ref={parentDivRef}>
      <canvas ref={canvasRef} />
    </div>
  );
};

export default PieceMap;
